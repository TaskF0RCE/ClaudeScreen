"""Appels système pour macOS et Linux : écrans, capture, souris, clavier, fenêtre active, corbeille.

Équivalent de natif.cs (version Windows). Trois cas :
  - macOS : Quartz/AppKit (pyobjc) + pynput ; capture avec l'outil système screencapture ;
  - Linux X11 : python-xlib + pynput (XTest) + mss ;
  - Linux Wayland : en partie seulement (capture via grim / gnome-screenshot / spectacle,
    contrôle via ydotool s'il est installé, sinon pynput à travers XWayland).

Les coordonnées sont celles de la souris : points sur macOS (pas les pixels Retina),
pixels sur Linux.
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


# ---------------------------------------------------------------- écrans

def moniteurs():
    """Liste des écrans : [{gauche, haut, largeur, hauteur}] dans l'espace de la souris."""
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
    # Wayland sans XWayland : on prend la taille d'une capture complète.
    img = _capture_complete_wayland()
    return [dict(gauche=0, haut=0, largeur=img.width, hauteur=img.height)]


def position_souris():
    """(x, y) de la souris, ou None si inconnue (Wayland)."""
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
    """Écran où se trouve la souris (le premier écran si la position est inconnue)."""
    liste = moniteurs()
    pos = position_souris()
    if pos:
        x, y = pos
        for m in liste:
            if m['gauche'] <= x < m['gauche'] + m['largeur'] and m['haut'] <= y < m['haut'] + m['hauteur']:
                return m
    return liste[0]


# ---------------------------------------------------------------- capture

def _image_vers_rgb(chemin):
    from PIL import Image
    with Image.open(chemin) as img:
        return img.convert('RGB')


def _grab_mac(gauche, haut, largeur, hauteur):
    """Capture d'une zone (en points) avec l'outil système ; l'image est en pixels réels (Retina)."""
    fd, tmp = tempfile.mkstemp(suffix='.png')
    os.close(fd)
    try:
        subprocess.run(['screencapture', '-x', '-t', 'png',
                        '-R', '%d,%d,%d,%d' % (gauche, haut, largeur, hauteur), tmp],
                       check=True, capture_output=True, timeout=20)
        if os.path.getsize(tmp) == 0:
            raise RuntimeError('capture vide (autorisation « Enregistrement de l\'écran » manquante ?)')
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
    """Capture de tout le bureau sous Wayland avec l'outil disponible."""
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
        raise RuntimeError('capture impossible sous Wayland : installe grim (Sway, Hyprland), '
                           'gnome-screenshot (GNOME) ou spectacle (KDE), ou ouvre une session X11.')
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def _grab_wayland(gauche, haut, largeur, hauteur):
    img = _capture_complete_wayland()
    # La capture couvre tout le bureau ; on découpe la zone (avec le facteur d'échelle éventuel).
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
    """Capture la zone et l'enregistre en PNG.

    echelle : l'image fait (largeur/echelle) x (hauteur/echelle) pixels (comme la version Windows).
    echelle=None : résolution native (Retina comprise), réduite seulement au-delà de cote_max.
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


# ---------------------------------------------------------------- fenêtre active

def fenetre_active():
    """(nom de l'appli, titre de la fenêtre, identifiant pour la remettre au premier plan)."""
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
    """Remet au premier plan la fenêtre / l'appli mémorisée par fenetre_active()."""
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


# ---------------------------------------------------------------- souris et clavier

def _ydotool():
    """Sous Wayland, ydotool (uinput) est le seul moyen fiable de piloter toutes les fenêtres."""
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


def deplacer(x, y):
    if _ydotool():
        _yd('mousemove', '--absolute', '-x', int(round(x)), '-y', int(round(y)))
    elif MAC:
        _s().position = (x, y)  # points : les fractions sont permises
    else:
        _s().position = (int(round(x)), int(round(y)))  # X11 tronquerait 299,99 en 299
    time.sleep(0.03)


def clic(x, y, droit=False, nombre=1):
    deplacer(x, y)
    if _ydotool():
        _yd('click', '--repeat', nombre, '--next-delay', 60, '0xC1' if droit else '0xC0')
        return
    from pynput.mouse import Button
    # click(bouton, n) : sur macOS, c'est ce qui marque le 2e clic comme un double-clic.
    _s().click(Button.right if droit else Button.left, nombre)
    time.sleep(0.06)


def glisser(x1, y1, x2, y2):
    deplacer(x1, y1)
    if _ydotool():
        _yd('click', '0x40')
        for i in range(1, 21):
            _yd('mousemove', '--absolute', '-x', int(x1 + (x2 - x1) * i / 20), '-y', int(y1 + (y2 - y1) * i / 20))
        _yd('click', '0x80')
        return
    from pynput.mouse import Button
    s = _s()
    s.press(Button.left)
    time.sleep(0.05)
    for i in range(1, 21):
        s.position = (x1 + (x2 - x1) * i / 20.0, y1 + (y2 - y1) * i / 20.0) if MAC else (int(round(x1 + (x2 - x1) * i / 20.0)), int(round(y1 + (y2 - y1) * i / 20.0)))
        time.sleep(0.015)
    s.release(Button.left)


def molette(x, y, crans):
    """crans > 0 : monte ; crans < 0 : descend (1 cran = 3 lignes, comme sous Windows)."""
    deplacer(x, y)
    crans = int(crans)
    if MAC:
        import Quartz
        ev = Quartz.CGEventCreateScrollWheelEvent(None, Quartz.kCGScrollEventUnitLine, 1, crans * 3)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, ev)
    elif _ydotool():
        _yd('mousemove', '--wheel', '-x', 0, '-y', crans)
    else:
        _s().scroll(0, crans)


# Noms de touches acceptés -> nom pynput.
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

# Codes evdev (Linux) pour ydotool, disposition QWERTY.
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
    """Normalise un nom de touche ('Ctrl', 'F5', 'a'...) ; lève ValueError si inconnu."""
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
        raise ValueError('Touche indisponible sur ce système : %s' % nom)
    return t


class _ClavierX11:
    """Clavier X11 entièrement via XTest (comme xdotool).

    pynput envoie les caractères avec XSendEvent : ces événements « synthétiques » sont ignorés
    par une partie des applis (xterm, certaines applis Java/Qt) et cassent les raccourcis.
    Ici tout passe par XTest ; un caractère absent de la disposition du clavier est tapé en
    remappant un instant une touche libre.
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
        self.empruntes = {}  # keysym -> keycode remappé

    def _keysym(self, car):
        if car == '\n':
            return self.XK.string_to_keysym('Return')
        if car == '\t':
            return self.XK.string_to_keysym('Tab')
        o = ord(car)
        if 0x20 <= o <= 0x7e or 0xa0 <= o <= 0xff:
            return o  # Latin-1 : le keysym est le code du caractère
        return 0x01000000 | o  # keysym Unicode

    def _evenement(self, keycode, appui):
        from Xlib import X
        self.xtest.fake_input(self.d, X.KeyPress if appui else X.KeyRelease, keycode)
        self.d.sync()

    def _code(self, keysym):
        """(keycode, avec_maj) pour ce keysym, en remappant une touche libre au besoin."""
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
            raise ValueError('Aucune touche libre pour taper le caractère U+%04X' % (keysym & 0xFFFFFF))
        code = self.libres.pop()
        self.d.change_keyboard_mapping(code, [(keysym, keysym)])
        self.d.sync()
        time.sleep(0.03)  # laisse aux applis le temps de relire la disposition
        self.empruntes[keysym] = code
        self.restaurer.append(code)
        return code, False

    def taper(self, texte):
        try:
            for car in texte:
                code, maj = self._code(self._keysym(car))
                if maj:
                    self._evenement(self.shift, True)
                self._evenement(code, True)
                self._evenement(code, False)
                if maj:
                    self._evenement(self.shift, False)
                time.sleep(0.008)
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
        """Rend les touches remappées."""
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
    """Appuie sur les touches dans l'ordre puis les relâche dans l'ordre inverse (ex. ['ctrl', 'a'])."""
    noms = [_nom_touche(n) for n in noms if n.strip()]
    if not noms:
        raise ValueError('Aucune touche.')
    if _ydotool():
        codes = []
        for n in noms:
            if n not in _EVDEV:
                raise ValueError('Touche non gérée avec ydotool : %s' % n)
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


def taper(texte):
    """Tape le texte (Unicode) là où se trouve le curseur ; \\n = Entrée, \\t = Tab."""
    texte = texte.replace('\r\n', '\n').replace('\r', '\n')
    if _ydotool():
        _yd('type', '--key-delay', 8, '--', texte)
        return
    if not MAC:
        _clavier_x11().taper(texte)
        return
    from pynput.keyboard import Key, KeyCode
    c = _c()
    for ch in texte:
        if ch == '\n':
            t = Key.enter
        elif ch == '\t':
            t = Key.tab
        else:
            t = KeyCode.from_char(ch)
        c.press(t)
        c.release(t)
        time.sleep(0.008)


# ---------------------------------------------------------------- fichiers

def corbeille(chemin):
    """Met un fichier ou un dossier à la corbeille (jamais de suppression définitive)."""
    from send2trash import send2trash
    send2trash(os.path.abspath(chemin))


def ouvrir(chemin):
    """Ouvre un dossier ou un fichier avec l'appli par défaut (Finder, gestionnaire de fichiers...)."""
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


# ---------------------------------------------------------------- autorisations (macOS)

def autorisations(demander=False):
    """macOS : {'ecran': bool, 'accessibilite': bool}. Avec demander=True, affiche les demandes système."""
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
