"""Small windows of the app, started in a separate process (Tk and the menu bar icon
cannot share the main thread on macOS).

  fenetres.py sessions              Sessions window; the state of the app comes as JSON on stdin
                                    (see Appli.etat_sessions); closes when you click elsewhere
  fenetres.py consigne X Y          instruction bar; X Y = bottom-left corner of the captured screen.
                                    Enter: prints the text on stdout, exit code 0.
                                    Esc / click elsewhere: exit code 1.

Without Tk: falls back to osascript (macOS), zenity or kdialog (Linux).
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sessions  # noqa: E402

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
            pass  # focus_get fails on some widgets of the window itself (a drop-down list): still in the window

    root.bind('<FocusIn>', entree, add='+')
    root.bind('<FocusOut>', lambda _e: root.after(200, verifier), add='+')


# ------------------------------------------------------------------ Sessions window

def envoyer(chemin_socket, commande):
    """Sends an action (a dict, see Appli.commande_sessions) to the app through its control socket and returns
    its answer: the new state of the sessions, or None when the app cannot be reached."""
    import socket
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.settimeout(12)
        s.connect(chemin_socket)
        s.sendall(('sessions ' + json.dumps(commande)).encode('utf-8'))
        s.shutdown(socket.SHUT_WR)
        morceaux = []
        while True:
            m = s.recv(65536)
            if not m:
                break
            morceaux.append(m)
        return json.loads(b''.join(morceaux).decode('utf-8'))
    except (OSError, ValueError):
        return None
    finally:
        s.close()


class FenetreSessions:
    """The Sessions window: the sessions (the one in use first), their tasks, a new session, resuming an
    earlier one, the choice between Persisted Memory and Ghost Mode, the roles and the documents of a session,
    and how long the tasks are kept. Same layout and behaviour as the Windows one.

    etat: what the app knows and no file holds (see Appli.etat_sessions): donnees, contexte, fantome, occupe,
    maintenant, titre_maintenant, entrees_fantome, roles_fantome. Every action goes to the app through
    envoyer(action), which returns the new state; the window then shows it. The window is small, sits in the
    bottom-right corner and can be resized: its size is kept in data/window.txt.
    """

    def __init__(self, etat, envoyer_commande, tk, ttk):
        self.tk = tk
        self.etat = etat
        self.envoyer = envoyer_commande
        self.donnees = etat['donnees']
        self.contexte = etat.get('contexte', '')
        self.choix, self.entrees, self.position = [], [], 0
        self.enregistrement = None
        self.dialogue = False   # a file dialog is open: losing the focus must not close the window
        root = self.root = tk.Tk()
        root.title('Claude-Work - Sessions')
        self.ecran = (root.winfo_screenwidth(), root.winfo_screenheight())
        self.taille = sessions.taille_fenetre(self.donnees, self.ecran)
        root.minsize(*sessions.TAILLE_MIN)
        self.placer()

        # Row 1: the sessions (the one in use first), Resume, New session.
        haut = tk.Frame(root)
        haut.pack(fill='x', padx=3, pady=(3, 0))
        self.nouvelle = tk.Button(haut, text='New session', command=lambda: self.action({'action': 'nouvelle'}))
        self.nouvelle.pack(side='right')
        self.reprendre = tk.Button(haut, text='Resume', command=self.reprendre_session)
        self.reprendre.pack(side='right')
        self.liste = ttk.Combobox(haut, state='readonly')
        self.liste.pack(side='left', fill='x', expand=True)
        self.liste.bind('<<ComboboxSelected>>', lambda _e: self.choisir(self.liste.current()))

        # Row 2: the mode of the session in use. One of the two is always selected.
        modes = tk.Frame(root)
        modes.pack(fill='x', padx=3)
        self.mode = tk.StringVar(value='persiste')
        self.persiste = tk.Radiobutton(modes, text='Persisted Memory', variable=self.mode, value='persiste',
                                       command=lambda: self.action({'action': 'fantome', 'actif': False}))
        self.persiste.pack(side='left')
        self.fantome = tk.Radiobutton(modes, text='Ghost Mode', variable=self.mode, value='fantome',
                                      command=lambda: self.action({'action': 'fantome', 'actif': True}))
        self.fantome.pack(side='left')
        # Only there when the window does not have its normal size.
        self.bouton_taille = tk.Button(modes, text='Default size', command=self.taille_defaut)

        # Row 3: the roles and the documents of the session shown. They apply to its next tasks.
        extras = tk.Frame(root)
        extras.pack(fill='x', padx=3, pady=1)
        self.bouton_documents = tk.Menubutton(extras, text='Documents (0)', relief='raised', width=13)
        self.bouton_documents.pack(side='right')
        self.menu_documents = tk.Menu(self.bouton_documents, tearoff=0, postcommand=self.remplir_menu_documents)
        self.bouton_documents.config(menu=self.menu_documents)
        self.bouton_roles = tk.Menubutton(extras, text='Roles: ', relief='raised', anchor='w')
        self.bouton_roles.pack(side='left', fill='x', expand=True)
        self.menu_roles = tk.Menu(self.bouton_roles, tearoff=0, postcommand=self.remplir_menu_roles)
        self.bouton_roles.config(menu=self.menu_roles)

        # Row 4: the tasks of the session, older on the left, newer on the right.
        barre = tk.Frame(root)
        barre.pack(fill='x', padx=3)
        self.ancien = tk.Button(barre, text='<', width=3, command=lambda: self.aller(-1))
        self.ancien.pack(side='left')
        self.recent = tk.Button(barre, text='>', width=3, command=lambda: self.aller(1))
        self.recent.pack(side='right')
        self.titre = tk.Label(barre)
        self.titre.pack(side='left', fill='x', expand=True)

        # Bottom row, the one setting: how long the tasks of the kept sessions stay.
        bas = tk.Frame(root)
        bas.pack(side='bottom', fill='x', padx=6, pady=3)
        tk.Label(bas, text='Persisted sessions are kept for', anchor='w').pack(side='left', fill='x', expand=True)
        self.duree = ttk.Combobox(bas, state='readonly', width=8, values=[c[0] for c in sessions.CHOIX_CONSERVATION])
        self.duree.pack(side='right')
        self.duree.bind('<<ComboboxSelected>>', lambda _e: self.action(
            {'action': 'conservation', 'jours': dict(sessions.CHOIX_CONSERVATION)[self.duree.get()]}))

        cadre = tk.Frame(root, bg='white')
        cadre.pack(fill='both', expand=True)
        defilement = tk.Scrollbar(cadre)
        defilement.pack(side='right', fill='y')
        self.zone = tk.Text(cadre, wrap='word', relief='flat', bd=0, padx=10, pady=8, bg='white', fg='#1f1f1f',
                            font=('Helvetica' if MAC else 'TkDefaultFont', 13 if MAC else 11),
                            yscrollcommand=defilement.set, highlightthickness=0)
        self.zone.pack(side='left', fill='both', expand=True)
        defilement.config(command=self.zone.yview)

        self.remplir()
        root.bind('<Configure>', self.redimensionnee)
        root.bind('<Escape>', lambda _e: root.destroy())

    # ---- size and place

    def placer(self):
        """Bottom-right corner of the screen, whatever the size."""
        l, h = self.taille
        marge_bas = 90 if MAC else 60
        self.root.geometry('%dx%d+%d+%d' % (l, h, self.ecran[0] - l - 12, self.ecran[1] - h - marge_bas))

    def montrer_bouton_taille(self):
        if tuple(self.taille) == sessions.TAILLE_DEFAUT:
            self.bouton_taille.pack_forget()
        else:
            self.bouton_taille.pack(side='right')

    def redimensionnee(self, evenement):
        """A resize by the user is kept for the next times (written a moment later, not at every pixel)."""
        if evenement.widget is not self.root:
            return
        taille = (max(sessions.TAILLE_MIN[0], evenement.width), max(sessions.TAILLE_MIN[1], evenement.height))
        if taille == tuple(self.taille):
            return
        self.taille = taille
        self.montrer_bouton_taille()
        if self.enregistrement:
            self.root.after_cancel(self.enregistrement)
        self.enregistrement = self.root.after(400, self.enregistrer_taille)

    def enregistrer_taille(self):
        self.enregistrement = None
        sessions.enregistrer_taille(self.donnees, self.taille)

    def taille_defaut(self):
        self.taille = sessions.TAILLE_DEFAUT
        sessions.enregistrer_taille(self.donnees, self.taille)
        self.placer()
        self.montrer_bouton_taille()

    # ---- content

    def remplir(self):
        """Reads everything again and shows the session in use (the first of the list)."""
        e = self.etat
        self.choix = sessions.choix(self.donnees, e.get('fantome'), e.get('entrees_fantome') or (), self.contexte)
        self.liste.config(values=[s['titre'] for s in self.choix])
        self.liste.current(0)
        self.mode.set('fantome' if e.get('fantome') else 'persiste')
        libre = 'disabled' if e.get('occupe') else 'normal'
        for bouton in (self.nouvelle, self.persiste, self.fantome):
            bouton.config(state=libre)
        self.duree.set(sessions.choix_proche(sessions.conservation(self.donnees)))
        self.montrer_bouton_taille()
        self.choisir(0)

    def choisir(self, index):
        """Shows one session of the list, on its newest task. Resume is offered for a kept session that is not in use."""
        session = self.choix[index]
        e = self.etat
        self.entrees = sessions.entrees(session, e.get('maintenant'), e.get('titre_maintenant') or '')
        self.position = len(self.entrees) - 1
        reprenable = bool(session['id']) and not session['courante'] and not e.get('occupe')
        self.reprendre.config(state='normal' if reprenable else 'disabled')
        self.afficher_extras()
        self.afficher()

    # ---- roles and documents of the session shown

    def session_affichee(self):
        return self.choix[max(0, self.liste.current())]

    def possible(self, session):
        """A persisted session or the ghost one has roles and documents; "Earlier tasks" has neither."""
        return bool(session['id']) or session['fantome']

    def roles(self, session):
        return sessions.lire_roles(self.donnees, os.path.join(self.contexte, 'Roles'), session['id'],
                                   self.etat.get('roles_fantome') or ())

    def afficher_extras(self):
        s = self.session_affichee()
        if not self.possible(s) or not self.contexte:
            self.bouton_roles.config(text='Roles: -', state='disabled')
            self.bouton_documents.config(text='Documents', state='disabled')
            return
        self.bouton_roles.config(text='Roles: ' + sessions.nom_roles(self.roles(s)), state='normal')
        self.bouton_documents.config(text='Documents (%d)' % len(sessions.lister_documents(self.contexte, s['id'])),
                                     state='normal')

    def remplir_menu_roles(self):
        """One item per role of System-Context/Roles, ticked when the session has it. General assistant (no
        specific role) unticks the others."""
        s = self.session_affichee()
        m = self.menu_roles
        m.delete(0, 'end')
        if not self.possible(s):
            return
        choisis = self.roles(s)
        self.coches = {}
        for nom in sessions.lister_roles(os.path.join(self.contexte, 'Roles')):
            v = self.coches[nom] = self.tk.BooleanVar(value=(not choisis) if nom == sessions.ROLE_PAR_DEFAUT else nom in choisis)
            m.add_checkbutton(label=nom, variable=v,
                              command=lambda n=nom: self.action({'action': 'role', 'id': s['id'], 'nom': n}, garder=True))
        m.add_separator()
        m.add_command(label='Open the Roles folder (edit or add a role)',
                      command=lambda: ouvrir(os.path.join(self.contexte, 'Roles')))

    def remplir_menu_documents(self):
        """The documents of the session (open, remove), and adding some."""
        s = self.session_affichee()
        m = self.menu_documents
        m.delete(0, 'end')
        if not self.possible(s):
            return
        docs = sessions.lister_documents(self.contexte, s['id'])
        for chemin in docs:
            sous = self.tk.Menu(m, tearoff=0)
            sous.add_command(label='Open', command=lambda c=chemin: ouvrir(c))
            sous.add_command(label='Remove from this session' + ('' if s['fantome'] else ' (to the trash)'),
                             command=lambda c=chemin: self.action({'action': 'retirer', 'id': s['id'], 'chemin': c}, garder=True))
            m.add_cascade(label=os.path.basename(chemin), menu=sous)
        if not docs:
            m.add_command(label='No document in this session yet', state='disabled')
        m.add_separator()
        m.add_command(label='Add documents...', command=lambda: self.choisir_documents(s))
        if docs:
            m.add_command(label='Open the folder', command=lambda: ouvrir(sessions.dossier_documents(self.contexte, s['id'])))

    def choisir_documents(self, session):
        """Picks files to copy into the documents of the session (the originals are not touched)."""
        from tkinter import filedialog
        self.dialogue = True
        try:
            fichiers = filedialog.askopenfilenames(parent=self.root, title='Claude-Work - documents for this session')
        finally:
            self.dialogue = False
        if fichiers:
            self.action({'action': 'ajouter', 'id': session['id'], 'fichiers': list(fichiers)}, garder=True)
        _premier_plan(self.root)

    def aller(self, pas):
        # -1 = one task further back, +1 = one task closer to now. The newest task is the last one (3 / 3).
        self.position = max(0, min(len(self.entrees) - 1, self.position + pas))
        self.afficher()

    def afficher(self):
        entree = self.entrees[self.position]
        self.zone.config(state='normal')
        self.zone.delete('1.0', 'end')
        self.zone.insert('1.0', sessions.texte_entree(entree))
        self.zone.config(state='disabled')  # read-only (selecting and copying still work)
        self.titre.config(text='%d / %d   %s' % (self.position + 1, len(self.entrees), entree['titre']))
        self.ancien.config(state='normal' if self.position > 0 else 'disabled')
        self.recent.config(state='normal' if self.position < len(self.entrees) - 1 else 'disabled')

    # ---- actions (done by the app, which answers with the new state)

    def reprendre_session(self):
        self.action({'action': 'reprendre', 'id': self.choix[self.liste.current()]['id']})

    def action(self, commande, garder=False):
        """Sends an action to the app, then shows the new state. garder: stay on the session shown (a change to
        its roles or documents), instead of going back to the session in use."""
        affichee = self.session_affichee()['id'] if garder and self.choix else None
        etat = self.envoyer(commande)
        if isinstance(etat, dict) and 'donnees' in etat:
            self.etat = etat
        else:
            self.etat = dict(self.etat, maintenant='The app did not answer. Is ClaudeScreen still running?',
                             titre_maintenant='last message')
        self.remplir()
        if affichee is not None:
            for i, s in enumerate(self.choix):
                if s['id'] == affichee:   # the first one: the ghost session comes before "Earlier tasks"
                    if i:
                        self.liste.current(i)
                        self.choisir(i)
                    break


def fenetre_sessions(etat):
    try:
        import tkinter as tk
        from tkinter import ttk
    except ImportError:
        return _sessions_sans_tk(etat)
    f = FenetreSessions(etat, lambda commande: envoyer(etat.get('socket', ''), commande), tk, ttk)
    _fermer_si_quitte(f.root, lambda: None if f.dialogue else f.root.destroy())
    f.root.after(50, lambda: _premier_plan(f.root))
    f.root.mainloop()
    return 0


def _sessions_sans_tk(etat):
    """Without Tk: the newest entry of the session in use, in a plain text window."""
    liste = sessions.choix(etat['donnees'], etat.get('fantome'), etat.get('entrees_fantome') or (), etat.get('contexte', ''))
    entree = sessions.entrees(liste[0], etat.get('maintenant'), etat.get('titre_maintenant') or '')[-1]
    if entree.get('fichier'):
        return _resultat_sans_tk(entree['fichier'])
    import tempfile
    with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False, encoding='utf-8') as f:
        f.write(sessions.texte_entree(entree))
    try:
        return _resultat_sans_tk(f.name)
    finally:
        try:
            os.remove(f.name)
        except OSError:
            pass


def ouvrir(chemin):
    """Opens a file or a folder with the default app (Finder, file manager...)."""
    subprocess.Popen(['open' if MAC else 'xdg-open', chemin], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


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
    if len(argv) >= 1 and argv[0] == 'sessions':
        return fenetre_sessions(json.loads(sys.stdin.buffer.read().decode('utf-8')))
    if len(argv) >= 3 and argv[0] == 'consigne':
        return consigne(float(argv[1]), float(argv[2]))
    sys.stderr.write(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
