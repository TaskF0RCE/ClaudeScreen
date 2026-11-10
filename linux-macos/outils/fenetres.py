"""Small windows of the app, started in a separate process (Tk and the menu bar icon
cannot share the main thread on macOS).

  fenetres.py resultat FILE         "last result" window (closes when you click elsewhere)
  fenetres.py consigne X Y          instruction bar; X Y = bottom-left corner of the captured screen.
                                    Enter: prints the text on stdout, exit code 0.
                                    Esc / click elsewhere: exit code 1.

Without Tk: falls back to osascript (macOS), zenity or kdialog (Linux).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys

MAC = sys.platform == 'darwin'
WAYLAND = (not MAC) and (bool(os.environ.get('WAYLAND_DISPLAY'))
                         or os.environ.get('XDG_SESSION_TYPE', '').lower() == 'wayland')
ORANGE = '#D97757'


def _premier_plan(root):
    root.lift()
    root.attributes('-topmost', True)
    if MAC:
        try:
            import AppKit
            app = AppKit.NSApplication.sharedApplication()
            app.setActivationPolicy_(1)  # accessory: no icon in the Dock
            app.activateIgnoringOtherApps_(True)
        except Exception:
            pass
    root.focus_force()


def _fermer_si_quitte(root, action):
    """Calls action() when the window loses focus (after having had it once)."""
    etat = {'eu': False}

    def entree(_e):
        etat['eu'] = True

    def verifier():
        try:
            if etat['eu'] and root.focus_get() is None:
                action()
        except Exception:
            action()

    root.bind('<FocusIn>', entree, add='+')
    root.bind('<FocusOut>', lambda _e: root.after(200, verifier), add='+')


# ------------------------------------------------------------------ result

def resultat(fichier):
    with open(fichier, encoding='utf-8') as f:
        texte = f.read()
    try:
        import tkinter as tk
    except ImportError:
        return _resultat_sans_tk(fichier)

    root = tk.Tk()
    root.title('Claude-Work')
    l, h = 520, 360
    marge_bas = 90 if MAC else 60
    root.geometry('%dx%d+%d+%d' % (l, h, root.winfo_screenwidth() - l - 12, root.winfo_screenheight() - h - marge_bas))
    cadre = tk.Frame(root, bg='white')
    cadre.pack(fill='both', expand=True)
    barre = tk.Scrollbar(cadre)
    barre.pack(side='right', fill='y')
    zone = tk.Text(cadre, wrap='word', relief='flat', bd=0, padx=10, pady=8, bg='white', fg='#1f1f1f',
                   font=('Helvetica' if MAC else 'TkDefaultFont', 13 if MAC else 11),
                   yscrollcommand=barre.set, highlightthickness=0)
    zone.pack(side='left', fill='both', expand=True)
    barre.config(command=zone.yview)
    zone.insert('1.0', texte)
    zone.config(state='disabled')  # read-only (selecting and copying still work)
    root.bind('<Escape>', lambda _e: root.destroy())
    _fermer_si_quitte(root, root.destroy)
    root.after(50, lambda: _premier_plan(root))
    root.mainloop()
    return 0


def _resultat_sans_tk(fichier):
    if MAC:
        subprocess.run(['open', '-e', fichier])
    elif shutil.which('zenity'):
        subprocess.run(['zenity', '--text-info', '--title=Claude-Work', '--width=520', '--height=360',
                        '--filename=' + fichier])
    elif shutil.which('kdialog'):
        subprocess.run(['kdialog', '--title', 'Claude-Work', '--textbox', fichier, '520', '360'])
    else:
        subprocess.run(['xdg-open', fichier])
    return 0


# ------------------------------------------------------------------ instruction bar

def consigne(x, y):
    try:
        import tkinter as tk
    except ImportError:
        return _consigne_sans_tk()

    root = tk.Tk()
    etat = {'fini': False, 'valide': False}
    sans_bord = not MAC and not WAYLAND
    if sans_bord:
        root.overrideredirect(True)  # unobtrusive bar, no title (X11)
        l, h, marge = 220, 22, 48
    else:
        root.title('Instruction for Claude')
        l, h, marge = 340, 28, 100 if MAC else 60
    root.geometry('%dx%d+%d+%d' % (l, h, int(x) + 6, int(y) - h - marge))
    root.configure(bg=ORANGE)
    try:
        root.attributes('-alpha', 0.94)
    except Exception:
        pass

    fond = tk.Frame(root, bg='white')
    fond.pack(fill='both', expand=True, padx=1, pady=1)
    champ = tk.Entry(fond, relief='flat', bd=0, highlightthickness=0, bg='white', fg='#1f1f1f',
                     insertbackground='#1f1f1f', font=('Helvetica' if MAC else 'TkDefaultFont', 12 if MAC else 9))
    champ.pack(fill='both', expand=True, padx=4)
    indice = tk.Label(fond, text='Consigne...', bg='white', fg='#9a9a9a',
                      font=('Helvetica' if MAC else 'TkDefaultFont', 12 if MAC else 9))
    indice.place(x=5, rely=0.5, anchor='w')
    indice.bind('<Button-1>', lambda _e: champ.focus_set())

    def maj_indice(_e=None):
        if champ.get():
            indice.place_forget()
        else:
            indice.place(x=5, rely=0.5, anchor='w')

    def finir(valide):
        if etat['fini']:
            return
        etat['fini'] = True
        etat['valide'] = valide
        etat['texte'] = champ.get().strip()
        root.destroy()

    champ.bind('<KeyRelease>', maj_indice)
    root.bind('<Return>', lambda _e: finir(True))
    root.bind('<KP_Enter>', lambda _e: finir(True))
    root.bind('<Escape>', lambda _e: finir(False))
    root.protocol('WM_DELETE_WINDOW', lambda: finir(False))
    _fermer_si_quitte(root, lambda: finir(False))

    def focus():
        _premier_plan(root)
        champ.focus_force()

    root.after(30, focus)
    root.after(250, focus)  # second try: some window managers are slow
    root.mainloop()

    if etat['valide']:
        sys.stdout.write(etat.get('texte', ''))
        sys.stdout.flush()
        return 0
    return 1


def _consigne_sans_tk():
    if MAC:
        script = ('try\n'
                  'set r to display dialog "Instruction for Claude:" default answer "" with title "Claude" '
                  'buttons {"Annuler", "OK"} default button "OK" cancel button "Annuler"\n'
                  'return text returned of r\n'
                  'on error\nreturn "\u0001ANNULE"\nend try')
        r = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
    elif shutil.which('zenity'):
        r = subprocess.run(['zenity', '--entry', '--title=Claude-Work', '--text=Instruction for Claude:'],
                           capture_output=True, text=True)
    elif shutil.which('kdialog'):
        r = subprocess.run(['kdialog', '--title', 'Claude-Work', '--inputbox', 'Instruction for Claude:'],
                           capture_output=True, text=True)
    else:
        sys.stderr.write('Neither Tk, zenity nor kdialog: instruction bar unavailable.\n')
        return 2
    texte = (r.stdout or '').strip()
    if r.returncode != 0 or texte == '\u0001ANNULE':
        return 1
    sys.stdout.write(texte)
    return 0


def main(argv):
    if len(argv) >= 2 and argv[0] == 'resultat':
        return resultat(argv[1])
    if len(argv) >= 3 and argv[0] == 'consigne':
        return consigne(float(argv[1]), float(argv[2]))
    sys.stderr.write(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
