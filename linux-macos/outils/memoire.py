"""instructions.md and memory.md in System-Context (equivalent of memoire.ps1).

  instructions.md: the user's standing instructions. It is the user's file: once it exists,
    neither the app nor Claude ever changes it.
  memory.md: Claude's notes (persistent memory). While "Persistent memory" is checked in the icon
    menu, the app saves there the "MEMORY: ..." lines found at the end of Claude's final answer.
    Unchecking the mode empties the file (the notes it held are kept once in data/memory-previous.md).
Comments (<!-- ... -->) are ignored in both files.
"""
from __future__ import annotations

import os
import re

COMMENTAIRE = re.compile(r'<!--.*?-->', re.DOTALL)
# A note in Claude's final answer: "MEMORY: text" (a list dash or bold around the word is accepted).
LIGNE_NOTE = re.compile(r'^\s*(?:[-*]\s+)?\**MEMORY\**\s*:\s*\**\s*(.*?)\s*$')
# The previous version kept the notes at the end of instructions.md, below a line of dashes.
ANCIEN_SEPARATEUR = re.compile(r'^[ \t]*-{10,}[ \t]*$', re.MULTILINE)
ANCIEN_ENTETE = "<!-- Claude's notes (persistent memory)"
ANCIEN_GABARIT = ('Keep the dashed line below. What you write above it is yours: it is never changed.\n'
                  'Below it, Claude writes its notes while "Persistent memory" is checked in the icon menu;\n'
                  'they are erased when you uncheck it.')
NOUVEAU_GABARIT = ('This file is yours: neither the app nor Claude ever changes it.\n'
                   "Claude's notes (Persistent memory in the icon menu) go to memory.md, next to this file.")
MAX_INSTRUCTIONS = 4000
MAX_NOTE = 300
MAX_MEMOIRE = 4000

ENTETE = """<!--
Claude's notes (persistent memory), one per line. The app adds them after each task
while "Persistent memory" is checked in the icon menu. You can edit or remove lines.
Unchecking the mode empties this file.
-->
"""

GABARIT = """<!--
Standing instructions for Claude (optional): write them below this comment, one per line.
They are added to every task ({normal} or {consigne}).
The instruction typed in the small bar takes priority over this file.
Comments like this one are ignored. You can also drop courses, PDFs or assignments
in this folder: Claude will read them if needed.

Examples:
I'm a second-year computer science student.
For quizzes: tick the answers and click Next, but never click "Finish exam".
Always answer in English.

""" + NOUVEAU_GABARIT + """
-->
"""


def active(fichier_etat):
    """True unless the user switched persistent memory off (data/memory.txt contains "off")."""
    return lire(fichier_etat).strip().lower() != 'off'


def lire(chemin):
    try:
        with open(chemin, encoding='utf-8-sig', errors='replace') as f:
            return f.read()
    except OSError:
        return ''


def ecrire(chemin, texte):
    with open(chemin, 'w', encoding='utf-8') as f:
        f.write(texte)


def nettoyer(texte):
    """Text without comments or empty lines."""
    lignes = (l.rstrip() for l in COMMENTAIRE.sub('', texte).splitlines())
    return '\n'.join(l for l in lignes if l.strip())


def instructions(chemin):
    """The user's instructions (instructions.md), cleaned, 4000 characters at most."""
    return nettoyer(lire(chemin))[:MAX_INSTRUCTIONS]


def coupe(chemin):
    """True when the file holds more than instructions() sends: its end is left out."""
    return len(nettoyer(lire(chemin))) > MAX_INSTRUCTIONS


def notes(chemin):
    """Claude's notes (memory.md), cleaned, 4000 characters at most."""
    return nettoyer(lire(chemin))[:MAX_MEMOIRE]


def preparer(chemin):
    """Creates memory.md (comment only) if it does not exist."""
    if not os.path.exists(chemin):
        ecrire(chemin, ENTETE)


def vider(chemin, sauvegarde=None):
    """Persistent memory turned off: memory.md is emptied (its comment stays). True if it held notes.

    The notes it held are copied first to sauvegarde, one file that is replaced each time: a click by
    mistake can be undone, and the trash does not fill up with one memory.md per click.
    """
    if not os.path.exists(chemin) or not notes(chemin):
        return False
    if sauvegarde:
        ecrire(sauvegarde, lire(chemin))
    ecrire(chemin, ENTETE)
    return True


def extraire(reponse):
    """Splits Claude's final answer: (what the user sees, the "MEMORY: ..." lines)."""
    texte, trouvees = [], []
    for ligne in reponse.splitlines():
        m = LIGNE_NOTE.match(ligne)
        if m:
            if m.group(1):
                trouvees.append(m.group(1))
        else:
            texte.append(ligne)
    return '\n'.join(texte).strip(), trouvees


def ajouter(chemin, nouvelles):
    """Adds notes at the end of memory.md (created if needed).

    One line per note, 300 characters at most; a note already there is skipped.
    The notes hold 4000 characters in all: when a new one does not fit, the oldest ones (the first lines)
    are removed to make room. Returns (number of notes written, number of old notes removed).
    """
    preparer(chemin)
    lignes = lire(chemin).rstrip().split('\n')
    existantes = nettoyer('\n'.join(lignes))
    deja = {re.sub(r'^\s*-\s*', '', l).strip() for l in existantes.split('\n')}
    taille = len(existantes)
    ajoutees, retirees = 0, 0
    for note in nouvelles:
        note = re.sub(r'^-\s*', '', ' '.join(note.replace('<!--', '').replace('-->', '').split()))
        if len(note) > MAX_NOTE:
            note = note[:MAX_NOTE - 3].rstrip() + '...'
        if not note or note in deja:
            continue
        while taille + len(note) + 3 > MAX_MEMOIRE:
            i = next((n for n, l in enumerate(lignes) if re.match(r'\s*-\s', l)), None)
            if i is None:
                break
            taille -= len(lignes.pop(i).rstrip()) + 1
            retirees += 1
        lignes.append('- ' + note)
        taille += len(note) + 3
        deja.add(note)
        ajoutees += 1
    if ajoutees:
        ecrire(chemin, '\n'.join(lignes) + '\n')
    return ajoutees, retirees


def migrer(ancien, nouveau, corbeille):
    """instructions.txt (older versions) -> instructions.md: lines starting with # become comments.

    The old file goes to the trash (corbeille = function that does it).
    """
    if not os.path.exists(ancien) or os.path.exists(nouveau):
        return False
    lignes = []
    for ligne in lire(ancien).splitlines():
        if ligne.lstrip().startswith('#'):
            reste = ligne.lstrip()[1:].strip().replace('--', '- -')
            # The old templates said that # lines are ignored: no longer true in instructions.md.
            reste = re.sub(r'^(Lines starting with # are ignored|Les lignes qui commencent par # sont ignor.es)\b.*$',
                           'Comments like this one are ignored. Write your instructions below, one per line.', reste)
            ligne = '<!-- %s -->' % reste if reste else ''
        lignes.append(ligne.rstrip())
    ecrire(nouveau, '\n'.join(lignes).rstrip() + '\n')
    corbeille(ancien)
    return True


def migrer_memoire(fichier_instructions, fichier_memoire):
    """Notes kept at the end of instructions.md by the previous version -> memory.md. Done once.

    That end (which the app had added) leaves instructions.md. Nothing is changed unless what follows
    the dashes is the app's own section: its comment, then only "- note" lines.
    """
    texte = lire(fichier_instructions).replace('\r\n', '\n')
    m = ANCIEN_SEPARATEUR.search(texte)
    if not m:
        return False
    fin = texte[m.end():]
    if ANCIEN_ENTETE not in fin:
        return False
    anciennes = [l for l in nettoyer(fin).split('\n') if l]
    if any(not re.match(r'\s*- ', l) for l in anciennes):
        return False
    if anciennes:
        ajouter(fichier_memoire, anciennes)
    # The old template explained the dashed line: say where the notes go now.
    ecrire(fichier_instructions, texte[:m.start()].rstrip().replace(ANCIEN_GABARIT, NOUVEAU_GABARIT) + '\n')
    return True
