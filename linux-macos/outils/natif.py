"""System calls for macOS and Linux: screens, screenshot, mouse, keyboard, active window, trash.

Equivalent of natif.cs (Windows version). Three cases:
  - macOS: Quartz/AppKit (pyobjc) + pynput; screenshots with the system screencapture tool;
  - Linux X11: python-xlib + pynput (XTest) + mss;
  - Linux Wayland: partial only (screenshots via grim / gnome-screenshot / spectacle,
    control via ydotool if installed, otherwise pynput through XWayland).

Coordinates are mouse coordinates: points on macOS (not Retina pixels),
pixels on Linux.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import time

MAC = sys.platform == 'darwin'
LINUX = sys.platform.startswith('linux')


def _session():
    if MAC:
        return 'mac'
    if os.environ.get('WAYLAND_DISPLAY') or os.environ.get('XDG_SESSION_TYPE', '').lower() == 'wayland':
        return 'wayland'
    return 'x11'


SESSION = _session()


# ---------------------------------------------------------------- screens

def moniteurs():
    """List of screens: [{gauche, haut, largeur, hauteur}] in mouse space."""
    if MAC:
        try:
            import Quartz
            err, ids, n = Quartz.CGGetActiveDisplayList(16, None, None)
            liste = []
            for d in ids[:n]:
                b = Quartz.CGDisplayBounds(d)
                liste.append(dict(gauche=int(b.origin.x), haut=int(b.origin.y),
                                  largeur=int(b.size.width), hauteur=int(b.size.height)))
            if liste:
                return liste
        except Exception:
            pass
    try:
        import mss
        fabrique = getattr(mss, 'MSS', None) or mss.mss
        with fabrique() as s:
            liste = [dict(gauche=m['left'], haut=m['top'], largeur=m['width'], hauteur=m['height'])
                     for m in s.monitors[1:]]
        if liste:
            return liste
    except Exception:
        pass
    # Wayland without XWayland: use the size of a full screenshot.
    img = _capture_complete_wayland()
    return [dict(gauche=0, haut=0, largeur=img.width, hauteur=img.height)]


def position_souris():
    """(x, y) of the mouse, or None if unknown (Wayland)."""
    if MAC:
        import Quartz
        p = Quartz.CGEventGetLocation(Quartz.CGEventCreate(None))
        return (p.x, p.y)
    if SESSION == 'wayland':
        return None
    try:
        from Xlib import display
        d = display.Display()
        try:
            r = d.screen().root.query_pointer()
            return (r.root_x, r.root_y)
        finally:
            d.close()
    except Exception:
        return None


def ecran_sous_curseur():
    """Screen the mouse is on (the first screen if the position is unknown)."""
    liste = moniteurs()
    pos = position_souris()
    if pos:
        x, y = pos
        for m in liste:
            if m['gauche'] <= x < m['gauche'] + m['largeur'] and m['haut'] <= y < m['haut'] + m['hauteur']:
                return m
    return liste[0]


# ---------------------------------------------------------------- screenshot

def _image_vers_rgb(chemin):
    from PIL import Image
    with Image.open(chemin) as img:
        return img.convert('RGB')


def _grab_mac(gauche, haut, largeur, hauteur):
    """Screenshot of an area (in points) with the system tool; the image is in real pixels (Retina)."""
    fd, tmp = tempfile.mkstemp(suffix='.png')
    os.close(fd)
    try:
        subprocess.run(['screencapture', '-x', '-t', 'png',
                        '-R', '%d,%d,%d,%d' % (gauche, haut, largeur, hauteur), tmp],
                       check=True, capture_output=True, timeout=20)
        if os.path.getsize(tmp) == 0:
            raise RuntimeError('empty screenshot (missing "Screen Recording" permission?)')
        return _image_vers_rgb(tmp)
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def _grab_mss(gauche, haut, largeur, hauteur):
    import mss
    from PIL import Image
    fabrique = getattr(mss, 'MSS', None) or mss.mss
    with fabrique() as s:
        shot = s.grab({'left': int(gauche), 'top': int(haut), 'width': int(largeur), 'height': int(hauteur)})
        taille = (shot.size[0], shot.size[1])
        return Image.frombytes('RGB', taille, bytes(shot.bgra), 'raw', 'BGRX')


def _capture_complete_wayland():
    """Screenshot of the whole desktop on Wayland with the available tool."""
    fd, tmp = tempfile.mkstemp(suffix='.png')
    os.close(fd)
    essais = []
    if shutil.which('grim'):
        essais.append(['grim', tmp])
    if shutil.which('gnome-screenshot'):
        essais.append(['gnome-screenshot', '-f', tmp])
    if shutil.which('spectacle'):
        essais.append(['spectacle', '-b', '-n', '-f', '-o', tmp])
    try:
        for cmd in essais:
            try:
                subprocess.run(cmd, check=True, capture_output=True, timeout=20)
                if os.path.getsize(tmp) > 0:
                    return _image_vers_rgb(tmp)
            except Exception:
                continue
        raise RuntimeError('screenshot impossible on Wayland: install grim (Sway, Hyprland), '
                           'gnome-screenshot (GNOME) or spectacle (KDE), or open an X11 session.')
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def _grab_wayland(gauche, haut, largeur, hauteur):
    img = _capture_complete_wayland()
    # The screenshot covers the whole desktop; crop the area (with the scale factor, if any).
    try:
        liste = moniteurs()
        x0 = min(m['gauche'] for m in liste)
        y0 = min(m['haut'] for m in liste)
        total = max(m['gauche'] + m['largeur'] for m in liste) - x0
    except Exception:
        x0, y0, total = 0, 0, img.width
    k = img.width / float(total or img.width)
    boite = (int((gauche - x0) * k), int((haut - y0) * k),
             int((gauche - x0 + largeur) * k), int((haut - y0 + hauteur) * k))
    return img.crop(boite) if boite != (0, 0, img.width, img.height) else img


def _grab(gauche, haut, largeur, hauteur):
    if MAC:
        try:
            return _grab_mac(gauche, haut, largeur, hauteur)
        except Exception:
            return _grab_mss(gauche, haut, largeur, hauteur)
    if SESSION == 'wayland':
        return _grab_wayland(gauche, haut, largeur, hauteur)
    return _grab_mss(gauche, haut, largeur, hauteur)


def capturer(chemin, gauche, haut, largeur, hauteur, echelle=None, cote_max=None):
    """Captures the area and saves it as PNG.

    echelle: the image is (largeur/echelle) x (hauteur/echelle) pixels (like the Windows version).
    echelle=None: native resolution (Retina included), scaled down only beyond cote_max.
    """
    from PIL import Image
    img = _grab(gauche, haut, largeur, hauteur)
    if echelle:
        cible = (max(1, int(round(largeur / echelle))), max(1, int(round(hauteur / echelle))))
    elif cote_max and max(img.size) > cote_max:
        k = cote_max / float(max(img.size))
        cible = (max(1, int(img.width * k)), max(1, int(img.height * k)))
    else:
        cible = img.size
    if img.size != cible:
        img = img.resize(cible, getattr(Image, 'LANCZOS', 1))
    img.save(chemin, 'PNG')
    return img.size


# ---------------------------------------------------------------- active window

def fenetre_active():
    """(app name, window title, id used to bring it back to the front)."""
    if MAC:
        return _fenetre_active_mac()
    if SESSION == 'x11':
        try:
            return _fenetre_active_x11()
        except Exception:
            pass
    return ('', '', None)


def _fenetre_active_mac():
    try:
        import Quartz
        options = Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements
        for w in Quartz.CGWindowListCopyWindowInfo(options, Quartz.kCGNullWindowID) or []:
            if w.get('kCGWindowLayer', 1) == 0 and w.get('kCGWindowOwnerName'):
                return (str(w.get('kCGWindowOwnerName', '')), str(w.get('kCGWindowName', '') or ''),
                        int(w.get('kCGWindowOwnerPID', 0)) or None)
    except Exception:
        pass
    try:
        import AppKit
        app = AppKit.NSWorkspace.sharedWorkspace().frontmostApplication()
        return (str(app.localizedName()), '', int(app.processIdentifier()))
    except Exception:
        return ('', '', None)


def _fenetre_active_x11():
    from Xlib import X, display
    d = display.Display()
    try:
        racine = d.screen().root
        prop = racine.get_full_property(d.intern_atom('_NET_ACTIVE_WINDOW'), X.AnyPropertyType)
        if not prop or not prop.value or not prop.value[0]:
            return ('', '', None)
        wid = int(prop.value[0])
        w = d.create_resource_object('window', wid)
        titre = ''
        p = w.get_full_property(d.intern_atom('_NET_WM_NAME'), d.intern_atom('UTF8_STRING'))
        if p and p.value:
            titre = p.value.decode('utf-8', 'replace') if isinstance(p.value, bytes) else str(p.value)
        else:
            titre = w.get_wm_name() or ''
        nom = ''
        p = w.get_full_property(d.intern_atom('_NET_WM_PID'), X.AnyPropertyType)
        if p and p.value:
            try:
                with open('/proc/%d/comm' % p.value[0]) as f:
                    nom = f.read().strip()
            except OSError:
                pass
        if not nom:
            classe = w.get_wm_class()
            nom = classe[1] if classe else ''
        return (nom, titre, wid)
    finally:
        d.close()


def activer(ident):
    """Brings back to the front the window / app remembered by fenetre_active()."""
    if not ident:
        return
    try:
        if MAC:
            import AppKit
            app = AppKit.NSRunningApplication.runningApplicationWithProcessIdentifier_(ident)
            if app:
                app.activateWithOptions_(1 << 1)  # NSApplicationActivateIgnoringOtherApps
        elif SESSION == 'x11':
            from Xlib import X, display, protocol
            d = display.Display()
            try:
                racine = d.screen().root
                w = d.create_resource_object('window', ident)
                ev = protocol.event.ClientMessage(window=w, client_type=d.intern_atom('_NET_ACTIVE_WINDOW'),
                                                  data=(32, [2, X.CurrentTime, 0, 0, 0]))
                racine.send_event(ev, event_mask=X.SubstructureRedirectMask | X.SubstructureNotifyMask)
                d.flush()
            finally:
                d.close()
    except Exception:
        pass


# ---------------------------------------------------------------- mouse and keyboard

def _ydotool():
    """On Wayland, ydotool (uinput) is the only reliable way to drive every window."""
    return SESSION == 'wayland' and shutil.which('ydotool') is not None


def _yd(*args):
    subprocess.run(['ydotool'] + [str(a) for a in args], check=True, capture_output=True, timeout=30)


_souris = None
_clavier = None


def _s():
    global _souris
    if _souris is None:
        from pynput.mouse import Controller
        _souris = Controller()
    return _souris


def _c():
    global _clavier
    if _clavier is None:
        from pynput.keyboard import Controller
        _clavier = Controller()
    return _clavier


def _poser(x, y):
    """Puts the mouse at (x, y) at once, without waiting."""
    if _ydotool():
        _yd('mousemove', '--absolute', '-x', int(round(x)), '-y', int(round(y)))
    elif MAC:
        _s().position = (x, y)  # points: fractions are allowed
    else:
        _s().position = (int(round(x)), int(round(y)))  # X11 would truncate 299.99 to 299


def _fichier_position():
    """On Wayland the mouse position cannot be read: the last position we set is kept in the task folder."""
    run = os.environ.get('ECRAN_RUN')
    return os.path.join(run, 'mouse-position.txt') if run else None


def _depart():
    pos = position_souris()
    if pos is None and _fichier_position():
        try:
            with open(_fichier_position()) as f:
                x, y = f.read().split()
                pos = (float(x), float(y))
        except (OSError, ValueError):
            pos = None
    return pos


def _retenir(x, y):
    if SESSION == 'wayland' and _fichier_position():
        try:
            with open(_fichier_position(), 'w') as f:
                f.write('%s %s' % (x, y))
        except OSError:
            pass


def _glisser_vers(x, y, lenteur=1.0, courbe=1.0):
    """Smooth mode: human-like movement from the current position (see humain.py)."""
    import humain
    depart = _depart()
    if depart is None:
        _poser(x, y)  # unknown position (first move on Wayland): jump, then glide the next times
    else:
        humain.glisser(depart, (x, y), _poser, lenteur, courbe)
    _retenir(x, y)


def deplacer(x, y, doux=False):
    if doux:
        import humain
        _glisser_vers(x, y)
        humain.pause_avant_clic()
        return
    _poser(x, y)
    _retenir(x, y)
    time.sleep(0.03)


def clic(x, y, droit=False, nombre=1, doux=False):
    deplacer(x, y, doux)
    if _ydotool():
        delai = int(_entre_doux(70, 110)) if doux else 60
        _yd('click', '--repeat', nombre, '--next-delay', delai, '0xC1' if droit else '0xC0')
        return
    from pynput.mouse import Button
    # click(button, n): on macOS, this is what marks the 2nd click as a double-click.
    _s().click(Button.right if droit else Button.left, nombre)
    time.sleep(0.06)


def _entre_doux(a, b):
    import humain
    return humain.entre(a, b)


def glisser(x1, y1, x2, y2, doux=False):
    deplacer(x1, y1, doux)
    if doux:
        # Press, wait a little, drag slowly in an almost straight line, wait, release.
        _bouton_gauche(True)
        time.sleep(_entre_doux(0.08, 0.14))
        _glisser_vers(x2, y2, lenteur=1.4, courbe=0.4)
        time.sleep(_entre_doux(0.08, 0.14))
        _bouton_gauche(False)
        return
    if _ydotool():
        _yd('click', '0x40')
        for i in range(1, 21):
            _yd('mousemove', '--absolute', '-x', int(x1 + (x2 - x1) * i / 20), '-y', int(y1 + (y2 - y1) * i / 20))
        _yd('click', '0x80')
        _retenir(x2, y2)
        return
    from pynput.mouse import Button
    s = _s()
    s.press(Button.left)
    time.sleep(0.05)
    for i in range(1, 21):
        s.position = (x1 + (x2 - x1) * i / 20.0, y1 + (y2 - y1) * i / 20.0) if MAC else (int(round(x1 + (x2 - x1) * i / 20.0)), int(round(y1 + (y2 - y1) * i / 20.0)))
        time.sleep(0.015)
    s.release(Button.left)


def _bouton_gauche(appui):
    if _ydotool():
        _yd('click', '0x40' if appui else '0x80')
        return
    from pynput.mouse import Button
    (_s().press if appui else _s().release)(Button.left)


def _cran(crans):
    if MAC:
        import Quartz
        ev = Quartz.CGEventCreateScrollWheelEvent(None, Quartz.kCGScrollEventUnitLine, 1, crans * 3)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
    elif _ydotool():
        _yd('mousemove', '--wheel', '-x', 0, '-y', crans)
    else:
        _s().scroll(0, crans)


def molette(x, y, crans, doux=False):
    """crans > 0: up; crans < 0: down (1 notch = 3 lines, like on Windows)."""
    deplacer(x, y, doux)
    crans = int(crans)
    if doux:
        # One notch at a time, like a finger on the wheel.
        sens = 1 if crans > 0 else -1
        for i in range(abs(crans)):
            if i:
                time.sleep(_entre_doux(0.07, 0.13))
            _cran(sens)
        return
    _cran(crans)


# Accepted key names -> pynput name.
NOMS_TOUCHES = {
    'ctrl': 'ctrl', 'control': 'ctrl', 'controle': 'ctrl',
    'alt': 'alt', 'option': 'alt', 'opt': 'alt',
    'shift': 'shift', 'maj': 'shift',
    'cmd': 'cmd', 'command': 'cmd', 'commande': 'cmd', 'super': 'cmd', 'win': 'cmd', 'meta': 'cmd',
    'enter': 'enter', 'entree': 'enter', 'return': 'enter',
    'tab': 'tab', 'esc': 'esc', 'escape': 'esc', 'echap': 'esc',
    'backspace': 'backspace', 'retour': 'backspace',
    'delete': 'delete', 'suppr': 'delete', 'del': 'delete', 'insert': 'insert',
    'space': 'space', 'espace': 'space',
    'home': 'home', 'debut': 'home', 'end': 'end', 'fin': 'end',
    'pageup': 'page_up', 'pagedown': 'page_down',
    'left': 'left', 'up': 'up', 'right': 'right', 'down': 'down',
    'gauche': 'left', 'haut': 'up', 'droite': 'right', 'bas': 'down',
}

# evdev codes (Linux) for ydotool, QWERTY layout.
_EVDEV = {
    'ctrl': 29, 'alt': 56, 'shift': 42, 'cmd': 125, 'enter': 28, 'tab': 15, 'esc': 1, 'backspace': 14,
    'delete': 111, 'insert': 110, 'space': 57, 'home': 102, 'end': 107, 'page_up': 104, 'page_down': 109,
    'left': 105, 'up': 103, 'right': 106, 'down': 108,
}
_EVDEV.update({'f%d' % i: 58 + i for i in range(1, 11)})
_EVDEV.update({'f11': 87, 'f12': 88})
_EVDEV.update(dict(zip('1234567890', range(2, 12))))
_EVDEV.update(dict(zip('qwertyuiop', range(16, 26))))
_EVDEV.update(dict(zip('asdfghjkl', range(30, 39))))
_EVDEV.update(dict(zip('zxcvbnm', range(44, 51))))


def _nom_touche(nom):
    """Normalises a key name ('Ctrl', 'F5', 'a'...); raises ValueError if unknown."""
    n = nom.strip().lower()
    if n in NOMS_TOUCHES:
        return NOMS_TOUCHES[n]
    if len(n) >= 2 and n[0] == 'f' and n[1:].isdigit() and 1 <= int(n[1:]) <= 20:
        return n
    if len(n) == 1 and (n.isalnum() or n in '-=[];\',./`\\'):
        return n
    raise ValueError('Touche inconnue : %s' % nom)


def _touche_pynput(nom):
    from pynput.keyboard import Key, KeyCode
    if len(nom) == 1:
        return KeyCode.from_char(nom)
    t = getattr(Key, nom, None)
    if t is None:
        raise ValueError('Key not available on this system: %s' % nom)
    return t


class _ClavierX11:
    """X11 keyboard entirely through XTest (like xdotool).

    pynput sends characters with XSendEvent: these "synthetic" events are ignored
    by some apps (xterm, some Java/Qt apps) and break shortcuts.
    Here everything goes through XTest; a character missing from the keyboard layout is typed
    by briefly remapping a free key.
    """
    NOMS_X = {
        'ctrl': 'Control_L', 'alt': 'Alt_L', 'shift': 'Shift_L', 'cmd': 'Super_L',
        'enter': 'Return', 'tab': 'Tab', 'esc': 'Escape', 'backspace': 'BackSpace', 'delete': 'Delete',
        'insert': 'Insert', 'space': 'space', 'home': 'Home', 'end': 'End', 'page_up': 'Prior',
        'page_down': 'Next', 'left': 'Left', 'up': 'Up', 'right': 'Right', 'down': 'Down',
    }

    def __init__(self):
        from Xlib import XK, display
        from Xlib.ext import xtest
        self.XK, self.xtest = XK, xtest
        self.d = display.Display()
        self.shift = self.d.keysym_to_keycode(XK.string_to_keysym('Shift_L'))
        self.libres = None
        self.empruntes = {}  # keysym -> remapped keycode

    def _keysym(self, car):
        if car == '\n':
            return self.XK.string_to_keysym('Return')
        if car == '\t':
            return self.XK.string_to_keysym('Tab')
        o = ord(car)
        if 0x20 <= o <= 0x7e or 0xa0 <= o <= 0xff:
            return o  # Latin-1: the keysym is the character code
        return 0x01000000 | o  # Unicode keysym

    def _evenement(self, keycode, appui):
        from Xlib import X
        self.xtest.fake_input(self.d, X.KeyPress if appui else X.KeyRelease, keycode)
        self.d.sync()

    def _code(self, keysym):
        """(keycode, avec_maj) for this keysym, remapping a free key if needed."""
        meilleur = None
        for code, index in self.d.keysym_to_keycodes(keysym):
            if index in (0, 1) and (meilleur is None or index < meilleur[1]):
                meilleur = (code, index)
        if meilleur:
            return meilleur[0], meilleur[1] == 1
        if keysym in self.empruntes:
            return self.empruntes[keysym], False
        if self.libres is None:
            info = self.d.display.info
            debut, fin = info.min_keycode, info.max_keycode
            table = self.d.get_keyboard_mapping(debut, fin - debut + 1)
            self.libres = [debut + i for i, syms in enumerate(table) if not any(syms)]
            self.restaurer = []
        if not self.libres:
            raise ValueError('No free key to type character U+%04X' % (keysym & 0xFFFFFF))
        code = self.libres.pop()
        self.d.change_keyboard_mapping(code, [(keysym, keysym)])
        self.d.sync()
        time.sleep(0.03)  # give apps time to reload the layout
        self.empruntes[keysym] = code
        self.restaurer.append(code)
        return code, False

    def taper(self, texte, delais=None):
        try:
            for i, car in enumerate(texte):
                code, maj = self._code(self._keysym(car))
                if maj:
                    self._evenement(self.shift, True)
                self._evenement(code, True)
                self._evenement(code, False)
                if maj:
                    self._evenement(self.shift, False)
                time.sleep(delais[i] if delais else 0.008)
        finally:
            self._rendre()

    def combo(self, noms):
        codes = []
        for n in noms:
            if n in self.NOMS_X:
                keysym = self.XK.string_to_keysym(self.NOMS_X[n])
            elif n[0] == 'f' and n[1:].isdigit():
                keysym = self.XK.string_to_keysym(n.upper())
            else:
                keysym = self._keysym(n)
            code = self.d.keysym_to_keycode(keysym)
            if not code:
                code = self._code(keysym)[0]
            codes.append(code)
        try:
            for c in codes:
                self._evenement(c, True)
                time.sleep(0.02)
            for c in reversed(codes):
                self._evenement(c, False)
                time.sleep(0.02)
        finally:
            self._rendre()

    def _rendre(self):
        """Restores the remapped keys."""
        if self.empruntes:
            time.sleep(0.05)
            for code in self.restaurer:
                self.d.change_keyboard_mapping(code, [(0, 0)])
            self.d.sync()
            self.libres.extend(self.restaurer)
            self.restaurer, self.empruntes = [], {}


_x11 = None


def _clavier_x11():
    global _x11
    if _x11 is None:
        _x11 = _ClavierX11()
    return _x11


def combo(noms):
    """Presses the keys in order, then releases them in reverse order (e.g. ['ctrl', 'a'])."""
    noms = [_nom_touche(n) for n in noms if n.strip()]
    if not noms:
        raise ValueError('Aucune touche.')
    if _ydotool():
        codes = []
        for n in noms:
            if n not in _EVDEV:
                raise ValueError('Key not supported with ydotool: %s' % n)
            codes.append(_EVDEV[n])
        _yd('key', *(['%d:1' % c for c in codes] + ['%d:0' % c for c in reversed(codes)]))
        return
    if not MAC:
        _clavier_x11().combo(noms)
        return
    c = _c()
    touches = [_touche_pynput(n) for n in noms]
    for t in touches:
        c.press(t)
        time.sleep(0.02)
    for t in reversed(touches):
        c.release(t)
        time.sleep(0.02)


def taper(texte, doux=False):
    """Types the text (Unicode) where the cursor is; \\n = Enter, \\t = Tab.

    doux (smooth mode): one key at a time at a human pace (see humain.py).
    """
    texte = texte.replace('\r\n', '\n').replace('\r', '\n')
    delais = None
    if doux:
        import humain
        delais = humain.delais_frappe(texte)
    if _ydotool():
        if not delais:
            _yd('type', '--key-delay', 8, '--', texte)
            return
        for car, delai in zip(texte, delais):
            _yd('type', '--key-delay', 0, '--', car)
            time.sleep(delai)
        return
    if not MAC:
        _clavier_x11().taper(texte, delais)
        return
    from pynput.keyboard import Key, KeyCode
    c = _c()
    for i, ch in enumerate(texte):
        if ch == '\n':
            t = Key.enter
        elif ch == '\t':
            t = Key.tab
        else:
            t = KeyCode.from_char(ch)
        c.press(t)
        c.release(t)
        time.sleep(delais[i] if delais else 0.008)


# ---------------------------------------------------------------- files

def corbeille(chemin):
    """Sends a file or folder to the trash (never a permanent deletion)."""
    from send2trash import send2trash
    send2trash(os.path.abspath(chemin))


def ouvrir(chemin):
    """Opens a folder or file with the default app (Finder, file manager...)."""
    subprocess.Popen(['open' if MAC else 'xdg-open', chemin],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def dossier_documents():
    if LINUX and shutil.which('xdg-user-dir'):
        try:
            d = subprocess.run(['xdg-user-dir', 'DOCUMENTS'], capture_output=True, text=True, timeout=5).stdout.strip()
            if d and d != os.path.expanduser('~') and os.path.isdir(d):
                return d
        except Exception:
            pass
    return os.path.join(os.path.expanduser('~'), 'Documents')


# ---------------------------------------------------------------- permissions (macOS)

def autorisations(demander=False):
    """macOS: {'ecran': bool, 'accessibilite': bool}. With demander=True, shows the system prompts."""
    if not MAC:
        return {}
    res = {}
    try:
        import Quartz
        res['ecran'] = bool(Quartz.CGPreflightScreenCaptureAccess())
        if demander and not res['ecran']:
            Quartz.CGRequestScreenCaptureAccess()
    except Exception:
        res['ecran'] = None
    try:
        import HIServices
        if demander:
            res['accessibilite'] = bool(HIServices.AXIsProcessTrustedWithOptions(
                {HIServices.kAXTrustedCheckOptionPrompt: True}))
        else:
            res['accessibilite'] = bool(HIServices.AXIsProcessTrusted())
    except Exception:
        res['accessibilite'] = None
    return res
