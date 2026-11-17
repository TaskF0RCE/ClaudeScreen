"""Sessions: which tasks belong together, their titles, roles and documents, how long they are kept, the size
of their window.

A session is a run of tasks that belong together: Claude keeps its notes from one task to the next, and
the Sessions window shows them as one history. Two modes:
  Persisted Memory (the default): every task folder (data/runs/<date>) holds the id of its session
    (session.txt), its instruction and its result. The notes of the current session are in
    System-Context/memory.md; those of the other sessions wait in data/sessions/<id>.md, so a session can
    be resumed with its context. Everything goes away with the task folders, after the time chosen.
  Ghost Mode: a session that only lives in the memory of the app. Nothing of it is written anywhere, and
    the documents added to it are deleted when it ends.
Each session has its roles (data/sessions/<id>.roles.txt; in memory for the ghost session) and its documents
(System-Context/Session documents/<id>/, "Ghost session" for the ghost one).

Only files are read and written here: no window, no call to Claude. Used by claude_screen.py (the app)
and by fenetres.py (the Sessions window, a separate process). Same logic as the Windows ClaudeScreen.ps1.
"""
from __future__ import annotations

import datetime
import hashlib
import os
import re
import shutil

ID_SESSION = re.compile(r'^\d{8}-\d{6}(-\d+)?$')
JOURS_PAR_DEFAUT = 30
CHOIX_CONSERVATION = (('7 days', 7), ('30 days', 30), ('90 days', 90), ('1 year', 365))
TAILLE_DEFAUT = (440, 420)   # the Sessions window: small, bottom-right corner
TAILLE_MIN = (380, 300)      # never too small to use
ROLE_PAR_DEFAUT = 'General assistant'   # no specific role
NOM_DOCUMENTS_FANTOME = 'Ghost session'
IGNORES = re.compile(r'^(\.|~\$|desktop\.ini$|thumbs\.db$|icon\r$)', re.IGNORECASE)   # not documents


def _lire(chemin):
    try:
        with open(chemin, encoding='utf-8-sig', errors='replace') as f:
            return f.read()
    except OSError:
        return ''


def _ecrire(chemin, texte):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    with open(chemin, 'w', encoding='utf-8') as f:
        f.write(texte)


def dossier(donnees):
    return os.path.join(donnees, 'sessions')


def lire_session(donnees):
    """Id of the current persisted session (the date it started), created when there is none."""
    fichier = os.path.join(donnees, 'session.txt')
    ident = _lire(fichier).strip()
    if not ID_SESSION.match(ident):
        ident = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
        _ecrire(fichier, ident)
    return ident


def nouvel_id(donnees, ancien, contexte=''):
    """An id for a session that starts now, different from the one that ends and from any session that still
    has something (two new sessions in the same second)."""
    base = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    ident, n = base, 2
    while (ident == ancien or any(os.path.exists(f(donnees, ident)) for f in (fichier_notes, fichier_titre, fichier_roles))
           or (contexte and os.path.exists(dossier_documents(contexte, ident)))):
        ident = '%s-%d' % (base, n)
        n += 1
    return ident


def fichier_notes(donnees, ident):
    return os.path.join(dossier(donnees), ident + '.md')


def fichier_titre(donnees, ident):
    return os.path.join(dossier(donnees), ident + '.title.txt')


def fichier_roles(donnees, ident):
    return os.path.join(dossier(donnees), ident + '.roles.txt')


# ------------------------------------------------------------------ roles

def lister_roles(dossier_roles):
    """Names of the roles (System-Context/Roles/<name>.md), General assistant first."""
    try:
        noms = sorted(n[:-3] for n in os.listdir(dossier_roles)
                      if n.lower().endswith('.md') and os.path.isfile(os.path.join(dossier_roles, n)))
    except OSError:
        noms = []
    return [n for n in noms if n == ROLE_PAR_DEFAUT] + [n for n in noms if n != ROLE_PAR_DEFAUT]


def lire_roles(donnees, dossier_roles, ident, roles_fantome=()):
    """The roles ticked for a session (ident '' = the ghost session, whose roles are roles_fantome): only those
    whose file is still there, without General assistant (= no specific role)."""
    noms = list(roles_fantome) if not ident else _lire(fichier_roles(donnees, ident)).splitlines()
    existants, vus = set(lister_roles(dossier_roles)), []
    for nom in (n.strip() for n in noms):
        if nom and nom != ROLE_PAR_DEFAUT and nom in existants and nom not in vus:
            vus.append(nom)
    return vus


def enregistrer_roles(donnees, ident, noms):
    """Saves the roles of a persisted session (nothing is kept when there is no specific role)."""
    noms = [n for i, n in enumerate(noms) if n and n != ROLE_PAR_DEFAUT and n not in noms[:i]]
    if noms:
        _ecrire(fichier_roles(donnees, ident), '\n'.join(noms) + '\n')
    else:
        try:
            os.remove(fichier_roles(donnees, ident))
        except OSError:
            pass
    return noms


def basculer_role(roles, nom):
    """Ticks or unticks one role. General assistant means no specific role: it unticks the others."""
    if nom == ROLE_PAR_DEFAUT:
        return []
    return [r for r in roles if r != nom] if nom in roles else list(roles) + [nom]


def nom_roles(roles):
    return ', '.join(roles) if roles else ROLE_PAR_DEFAUT


# Versions before 1.0 had contexts (System-Context/Contexts, one active for all tasks, data/context.txt)
# instead of roles. The context files as versions 0.6 to 0.9 installed them (SHA-256, LF, trimmed):
EMPREINTES_CONTEXTES = {
    '270dec11454d1fecaea7e3716c12fa16998458de3ad47ff0f2897089cbcb8490', '49f15cbade41b1a643d27d6a88cd119231039fc9ae18aadbaabb2df40f0cac51',
    'ed3a61232513c0fc8bc74da2b4154c322c021cdb7541300023681a6fe9d41c89', '1332bd0e1cfdf93ccb9b37e3b044ff3c036876a1328b01f7d7174ac5a0219a81',
    '7b2c3b2848ebf525bf7511c7cbe34f72af9d1fabea7f2d4dff3ff9eec0cc1533', 'cca023a7451218628ad5ec98f442a0de6b855b75fc9610dc6967cd4f57c15b4a',
    'cdbc40011a089a85a3cbb90e15c4200104ffe3811ab7ac6f641095d824f864f9', '79e6c3d4108e0682525f29af6692627c9cb6fb896d32435205f6667d4e621640',
    '96731d63e414cb092f909475b01dc34131cbbe2544109193a2f376acdbbc8afc'}
ROLES_DES_CONTEXTES = {
    'Default': 'General assistant', 'Networking': 'Network engineer', 'Software development': 'Software developer',
    'Studies': 'Student', 'IT administration': 'IT administrator', 'Defensive security': 'Security analyst',
    'Business and management': 'Business professional', 'Office productivity': 'Office assistant',
    'Personal use': 'Personal assistant'}


def empreinte(chemin):
    texte = _lire(chemin).replace('\r\n', '\n').strip()
    return hashlib.sha256(texte.encode('utf-8')).hexdigest()


def migrer_contextes(donnees, ancien_dossier, dossier_roles, corbeille, noter=lambda t: None):
    """Once: a context file the user wrote or changed becomes a role, the context that was active becomes the
    role of the current session, and the old folder goes to the trash."""
    fichier_contexte = os.path.join(donnees, 'context.txt')
    actif = _lire(fichier_contexte).strip()
    role = ''
    if os.path.isdir(ancien_dossier):
        for nom in sorted(os.listdir(ancien_dossier)):
            chemin = os.path.join(ancien_dossier, nom)
            if not nom.lower().endswith('.md') or not os.path.isfile(chemin) or empreinte(chemin) in EMPREINTES_CONTEXTES:
                continue  # as installed: its role replaces it
            cible = os.path.join(dossier_roles, nom)
            if os.path.exists(cible):
                cible = os.path.join(dossier_roles, nom[:-3] + ' (context).md')
            if not os.path.exists(cible):
                shutil.copyfile(chemin, cible)
                noter('Context %s kept as the role %s' % (nom[:-3], os.path.basename(cible)[:-3]))
            if nom[:-3] == actif:
                role = os.path.basename(cible)[:-3]
        corbeille(ancien_dossier)
        noter('Contexts replaced by Roles: the old Contexts folder is in the trash')
    if os.path.exists(fichier_contexte):
        role = role or ROLES_DES_CONTEXTES.get(actif, actif)
        ident = lire_session(donnees)
        if (role and role != ROLE_PAR_DEFAUT and os.path.isfile(os.path.join(dossier_roles, role + '.md'))
                and not os.path.exists(fichier_roles(donnees, ident))):
            enregistrer_roles(donnees, ident, [role])
            noter('Context %s: the current session has the role %s' % (actif, role))
        os.remove(fichier_contexte)


# ------------------------------------------------------------------ documents of a session

def dossier_documents(contexte, ident):
    """System-Context/Session documents/<id>, or "Ghost session" for the ghost session (ident '')."""
    return os.path.join(contexte, 'Session documents', ident or NOM_DOCUMENTS_FANTOME)


def lister_documents(contexte, ident):
    """The documents of a session (full paths), by name."""
    racine = dossier_documents(contexte, ident)
    fichiers = []
    for d, sous, noms in os.walk(racine):
        sous[:] = sorted(s for s in sous if not s.startswith('.'))
        fichiers += [os.path.join(d, n) for n in noms if not IGNORES.match(n) and os.path.isfile(os.path.join(d, n))]
    return sorted(fichiers, key=lambda c: os.path.basename(c).lower())


def ajouter_documents(contexte, ident, fichiers):
    """Copies files into the documents of a session (the originals are not touched); a name already there gets
    a number. Returns how many were added."""
    racine = dossier_documents(contexte, ident)
    os.makedirs(racine, exist_ok=True)
    n = 0
    for f in fichiers:
        if not os.path.isfile(f):
            continue
        base, ext = os.path.splitext(os.path.basename(f))
        cible, i = os.path.join(racine, base + ext), 2
        while os.path.exists(cible):
            cible, i = os.path.join(racine, '%s (%d)%s' % (base, i, ext)), i + 1
        shutil.copyfile(f, cible)
        n += 1
    return n


def retirer_document(contexte, ident, chemin, corbeille):
    """Removes one document of a session: to the trash, or deleted for the ghost session (a copy).
    Never a file outside the documents of that session."""
    racine = os.path.abspath(dossier_documents(contexte, ident)) + os.sep
    if not os.path.abspath(chemin).startswith(racine) or not os.path.isfile(chemin):
        return False
    if ident:
        corbeille(chemin)
    else:
        os.remove(chemin)
    return True


def vider_documents_fantome(contexte):
    shutil.rmtree(dossier_documents(contexte, ''), ignore_errors=True)


# ------------------------------------------------------------------ titles

def titre_propre(texte):
    """What Haiku answered, as a title: one line, no quotes, no markup, 3 to 60 characters. '' when it is not one."""
    lignes = [l.strip() for l in str(texte or '').splitlines() if l.strip()]
    if not lignes:
        return ''
    ligne = re.sub(r'[*_`"#«»“”]', '', lignes[0])
    ligne = re.sub(r'^\s*-\s+', '', ligne)
    ligne = re.sub(r'^\s*title\s*:\s*', '', ligne, flags=re.IGNORECASE)
    ligne = ' '.join(ligne.split()).rstrip('.').strip()
    return ligne if 3 <= len(ligne) <= 60 else ''


def lire_titre(donnees, ident):
    return titre_propre(_lire(fichier_titre(donnees, ident))) if ident else ''


def texte_titrage(langue, instruction, resultat):
    """The question put to Haiku: what the first task of the session was about."""
    return ('Give a title to this work session, like the title of a conversation: 2 to 6 words, in %s, saying what '
            'the user is working on. Answer with the title only: one line, no quotes, no final period.\n\n%s'
            'What was done in the first task of the session:\n%s\n' % (
                langue, 'What the user asked: %s\n\n' % instruction if instruction else '', str(resultat)[:1500]))


# ------------------------------------------------------------------ list of the sessions

def _date(nom, defaut=None):
    try:
        return datetime.datetime.strptime(nom[:15], '%Y%m%d-%H%M%S')
    except ValueError:
        return defaut


def _quand(d):
    return d.strftime('%d/%m/%Y %H:%M') if d else ''


def _nombre(n):
    return '1 task' if n == 1 else '%d tasks' % n


def lister(donnees, fantome=False, contexte=''):
    """The persisted sessions that still have a task, oldest first, plus the current one (even with no task yet).

    Each one: id, courante (the one in use; none in ghost mode), fantome (False), titre, taches (its kept
    tasks, oldest first: titre, fichier). Tasks older than the sessions are grouped in one, with no id.
    """
    runs = os.path.join(donnees, 'runs')
    courante = lire_session(donnees)
    taches = {}
    try:
        noms = sorted(os.listdir(runs))
    except OSError:
        noms = []
    for nom in noms:
        fichier = os.path.join(runs, nom, 'result.txt')
        if not os.path.isfile(fichier):
            continue
        ident = _lire(os.path.join(runs, nom, 'session.txt')).strip()
        d = _date(nom) or datetime.datetime.fromtimestamp(os.path.getmtime(fichier))
        taches.setdefault(ident, []).append({'titre': _quand(d), 'fichier': fichier, 'texte': None})
    taches.setdefault(courante, [])
    # A session that has documents but no task yet (or no more) is listed too: it can be resumed.
    if contexte:
        try:
            for nom in os.listdir(os.path.join(contexte, 'Session documents')):
                if ID_SESSION.match(nom) and nom not in taches and lister_documents(contexte, nom):
                    taches[nom] = []
        except OSError:
            pass
    sessions, numero = [], 0
    for ident in sorted(taches):
        en_cours = ident == courante and not fantome
        if ident:
            numero += 1
            # Its title when Haiku gave one, its number until then. What matters comes first: the end of
            # the title is cut in a narrow window.
            titre = (lire_titre(donnees, ident) or 'Session %d' % numero) + (' (current)' if en_cours else '')
            titre += '  -  ' + _quand(_date(ident))
        else:
            titre = 'Earlier tasks'
        titre += '  -  ' + _nombre(len(taches[ident]))
        sessions.append({'id': ident, 'courante': en_cours, 'fantome': False, 'titre': titre, 'taches': taches[ident]})
    return sessions


def session_fantome(entrees):
    """The ghost session, as the window shows it (entrees: its results, kept in memory by the app)."""
    return {'id': '', 'courante': True, 'fantome': True, 'taches': list(entrees),
            'titre': 'Ghost session (current)  -  ' + _nombre(len(entrees))}


def choix(donnees, fantome=False, entrees_fantome=(), contexte=''):
    """What the drop-down list offers: the session in use first, then the other persisted ones, newest first."""
    persistees = lister(donnees, fantome, contexte)
    liste = [session_fantome(entrees_fantome)] if fantome else []
    liste += [s for s in persistees if s['courante']]
    liste += [s for s in reversed(persistees) if not s['courante']]
    return liste


def entrees(session, maintenant=None, titre_maintenant=''):
    """What the window shows for one session, oldest first: its tasks, then, for the session in use, what is
    going on now when no task holds it (maintenant: a task in progress, a task that could not start)."""
    liste = list(session['taches'])
    if session['courante'] and maintenant is not None and titre_maintenant:
        liste.append({'titre': titre_maintenant, 'fichier': None, 'texte': maintenant})
    if not liste:
        liste.append({'titre': '', 'fichier': None,
                      'texte': maintenant if session['courante'] and maintenant is not None else 'This session has no task.'})
    return liste


def texte_entree(entree):
    """The text of one entry: what the app gave, or the result of the task after the instruction typed for it."""
    if entree.get('texte') is not None:
        return entree['texte']
    fichier = entree.get('fichier')
    if not fichier or not os.path.isfile(fichier):
        return 'This result is no longer kept.'
    texte = _lire(fichier)
    consigne = _lire(os.path.join(os.path.dirname(fichier), 'instruction.txt')).strip()
    return 'Instruction: %s\n\n%s' % (consigne, texte) if consigne else texte


# ------------------------------------------------------------------ how long the tasks are kept

def conservation(donnees):
    """Days the tasks of the persisted sessions are kept (data/retention.txt; 30 when absent or absurd)."""
    try:
        jours = int(_lire(os.path.join(donnees, 'retention.txt')).strip())
    except ValueError:
        return JOURS_PAR_DEFAUT
    return jours if 1 <= jours <= 3650 else JOURS_PAR_DEFAUT


def enregistrer_conservation(donnees, jours):
    _ecrire(os.path.join(donnees, 'retention.txt'), str(int(jours)))


def choix_proche(jours):
    """The choice of the window that is closest to a number of days."""
    return min(CHOIX_CONSERVATION, key=lambda c: abs(c[1] - jours))[0]


def nettoyer(donnees, garder=(), contexte='', limite=0.0, corbeille=None, noter=lambda t: None):
    """A session lives as long as it has a task, or documents added after limite (a time). When it ends, its
    notes, title and roles go away, and its documents go to the trash. garder: ids to keep whatever happens."""
    runs = os.path.join(donnees, 'runs')
    vivantes = set(garder)
    try:
        for nom in os.listdir(runs):
            ident = _lire(os.path.join(runs, nom, 'session.txt')).strip()
            if ident:
                vivantes.add(ident)
    except OSError:
        pass
    racine = os.path.join(contexte, 'Session documents') if contexte else ''
    try:
        docs = [n for n in os.listdir(racine) if ID_SESSION.match(n) and os.path.isdir(os.path.join(racine, n))] if racine else []
    except OSError:
        docs = []
    vivantes.update(n for n in docs if os.path.getmtime(os.path.join(racine, n)) >= limite)
    try:
        for nom in os.listdir(dossier(donnees)):
            if nom.split('.')[0] not in vivantes:
                os.remove(os.path.join(dossier(donnees), nom))
    except OSError:
        pass
    for nom in docs:
        if nom not in vivantes and corbeille:
            try:
                corbeille(os.path.join(racine, nom))
                noter('Session %s expired: its documents are in the trash' % nom)
            except Exception as ex:
                noter('Documents of session %s: %s' % (nom, ex))


# ------------------------------------------------------------------ size of the window

def taille_fenetre(donnees, ecran):
    """Size of the Sessions window: the one the user chose (data/window.txt), never below the minimum,
    never larger than the screen (ecran: its width and height)."""
    m = re.match(r'^\s*(\d{2,5})\s*[,x ]\s*(\d{2,5})\s*$', _lire(os.path.join(donnees, 'window.txt')))
    l, h = (int(m.group(1)), int(m.group(2))) if m else TAILLE_DEFAUT
    return (max(TAILLE_MIN[0], min(l, ecran[0] - 20)), max(TAILLE_MIN[1], min(h, ecran[1] - 20)))


def enregistrer_taille(donnees, taille):
    fichier = os.path.join(donnees, 'window.txt')
    if tuple(taille) == TAILLE_DEFAUT:
        try:
            os.remove(fichier)
        except OSError:
            pass
    else:
        _ecrire(fichier, '%d,%d' % tuple(taille))
