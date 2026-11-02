"""Global keyboard shortcuts (equivalent of the Raccourcis class in natif.cs).

  - macOS: RegisterEventHotKey (Carbon), like RegisterHotKey on Windows: no
    permission needed and other apps no longer receive the shortcut.
    Falls back to a pynput listener ("Input Monitoring" permission) if Carbon fails.
  - Linux X11: pynput listener (XRecord).
  - Linux Wayland: apps cannot listen to the global keyboard. The shortcut is
    declared in the desktop settings (installer.sh does it for GNOME) and calls
    "lancer.sh declencher" / "lancer.sh consigne".

Ids (same as the Windows version): 1 = normal task, 4 = with the instruction bar.
"""
from __future__ import annotations

import ctypes
import sys

MAC = sys.platform == 'darwin'

NORMAL = 1
CONSIGNE = 4


def noms():
    if MAC:
        return {NORMAL: '⌃⌥C', CONSIGNE: '⌃⌥⇧C'}
    return {NORMAL: 'Ctrl+Alt+C', CONSIGNE: 'Ctrl+Alt+Shift+C'}


def _fourcc(s):
    return int.from_bytes(s.encode('ascii'), 'big')


class Raccourcis:
    def __init__(self, sur_appui, journal=None):
        self.sur_appui = sur_appui
        self.journal = journal or (lambda texte: None)
        self._ecouteur = None
        self._carbon = None
        self._refs = []

    def demarrer(self):
        """Registers the shortcuts; returns the list of active shortcuts.
        On macOS, call it from the main thread (before the app loop)."""
        if MAC:
            try:
                return self._demarrer_carbon()
            except Exception as ex:
                self.journal('Carbon shortcuts unavailable (%s), falling back to pynput' % ex)
        try:
            return self._demarrer_pynput()
        except Exception as ex:
            self.journal('Keyboard listener unavailable: %s' % ex)
            return []

    # ------------------------------------------------------------ macOS (Carbon)

    def _demarrer_carbon(self):
        carbon = ctypes.CDLL('/System/Library/Frameworks/Carbon.framework/Carbon')

        class EventHotKeyID(ctypes.Structure):
            _fields_ = [('signature', ctypes.c_uint32), ('id', ctypes.c_uint32)]

        class EventTypeSpec(ctypes.Structure):
            _fields_ = [('eventClass', ctypes.c_uint32), ('eventKind', ctypes.c_uint32)]

        GESTIONNAIRE = ctypes.CFUNCTYPE(ctypes.c_int32, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p)
        carbon.GetApplicationEventTarget.restype = ctypes.c_void_p
        carbon.GetApplicationEventTarget.argtypes = []
        carbon.InstallEventHandler.restype = ctypes.c_int32
        carbon.InstallEventHandler.argtypes = [ctypes.c_void_p, GESTIONNAIRE, ctypes.c_ulong,
                                               ctypes.POINTER(EventTypeSpec), ctypes.c_void_p,
                                               ctypes.POINTER(ctypes.c_void_p)]
        carbon.RegisterEventHotKey.restype = ctypes.c_int32
        carbon.RegisterEventHotKey.argtypes = [ctypes.c_uint32, ctypes.c_uint32, EventHotKeyID, ctypes.c_void_p,
                                               ctypes.c_uint32, ctypes.POINTER(ctypes.c_void_p)]
        carbon.UnregisterEventHotKey.restype = ctypes.c_int32
        carbon.UnregisterEventHotKey.argtypes = [ctypes.c_void_p]
        carbon.GetEventParameter.restype = ctypes.c_int32
        carbon.GetEventParameter.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p,
                                             ctypes.c_ulong, ctypes.c_void_p, ctypes.c_void_p]

        def gestionnaire(_appel, evenement, _donnees):
            try:
                hk = EventHotKeyID()
                carbon.GetEventParameter(evenement, _fourcc('----'), _fourcc('hkid'), None,
                                         ctypes.sizeof(hk), None, ctypes.byref(hk))
                self.sur_appui(int(hk.id))
            except Exception:
                pass
            return 0

        self._gestionnaire = GESTIONNAIRE(gestionnaire)  # keep a reference (otherwise it is freed)
        cible = carbon.GetApplicationEventTarget()
        spec = EventTypeSpec(_fourcc('keyb'), 5)  # kEventClassKeyboard, kEventHotKeyPressed
        ref = ctypes.c_void_p()
        statut = carbon.InstallEventHandler(cible, self._gestionnaire, 1, ctypes.byref(spec), None, ctypes.byref(ref))
        if statut != 0:
            raise OSError('InstallEventHandler : %d' % statut)

        CONTROL, OPTION, SHIFT = 0x1000, 0x800, 0x200
        TOUCHE_C = 0x08  # kVK_ANSI_C (same position on QWERTY, AZERTY and QWERTZ)
        actifs = []
        for ident, mods in ((NORMAL, CONTROL | OPTION), (CONSIGNE, CONTROL | OPTION | SHIFT)):
            hk = ctypes.c_void_p()
            statut = carbon.RegisterEventHotKey(TOUCHE_C, mods, EventHotKeyID(_fourcc('CLEC'), ident),
                                                cible, 0, ctypes.byref(hk))
            if statut == 0:
                self._refs.append(hk)
                actifs.append(noms()[ident])
            else:
                self.journal('Shortcut %s refused (%d), already taken by another app?' % (noms()[ident], statut))
        if not actifs:
            raise OSError('no shortcut registered')
        self._carbon = carbon
        return actifs

    # ------------------------------------------------------------ pynput (X11, or macOS fallback)

    def _demarrer_pynput(self):
        from pynput import keyboard
        K = keyboard.Key
        modificateurs = {}
        for nom, generique in (('ctrl', 'ctrl'), ('ctrl_l', 'ctrl'), ('ctrl_r', 'ctrl'),
                               ('alt', 'alt'), ('alt_l', 'alt'), ('alt_r', 'alt'),
                               ('shift', 'shift'), ('shift_l', 'shift'), ('shift_r', 'shift'),
                               ('cmd', 'cmd'), ('cmd_l', 'cmd'), ('cmd_r', 'cmd')):
            t = getattr(K, nom, None)
            if t is not None:
                modificateurs[t] = generique
        enfonces = set()

        def est_c(touche):
            car = getattr(touche, 'char', None)
            vk = getattr(touche, 'vk', None)
            if car and car.lower() == 'c':
                return True
            return vk == 0x08 if MAC else vk in (0x63, 0x43)  # kVK_ANSI_C / keysyms c and C

        def appui(touche):
            if touche in modificateurs:
                enfonces.add(modificateurs[touche])
            elif est_c(touche):
                if enfonces == {'ctrl', 'alt'}:
                    self.sur_appui(NORMAL)
                elif enfonces == {'ctrl', 'alt', 'shift'}:
                    self.sur_appui(CONSIGNE)

        def relache(touche):
            if touche in modificateurs:
                enfonces.discard(modificateurs[touche])

        self._ecouteur = keyboard.Listener(on_press=appui, on_release=relache)
        self._ecouteur.daemon = True
        self._ecouteur.start()
        return [noms()[NORMAL], noms()[CONSIGNE]]

    def arreter(self):
        if self._ecouteur:
            try:
                self._ecouteur.stop()
            except Exception:
                pass
        if self._carbon:
            for hk in self._refs:
                try:
                    self._carbon.UnregisterEventHotKey(hk)
                except Exception:
                    pass
            self._refs = []
