"""instructions.md (System-Context) and persistent memory (equivalent of memoire.ps1).

instructions.md has two parts, split by a line of dashes (SEPARATEUR):
  - above: the user's standing instructions. Neither the app nor Claude ever changes them;
  - below: Claude's notes, added with "pc memoire" while "Persistent memory" is checked
    in the icon menu, and erased when it is unchecked.
Comments (<!-- ... -->) are ignored everywhere.
"""
from __future__ import annotations

import os
import re

SEPARATEUR = '---------------------'
# Any line made only of dashes (10 or more) counts, so the user can retype it by hand.
LIGNE_SEPARATEUR = re.compile(r'^[ \t]*-{10,}[ \t]*$', re.MULTILINE)
COMMENTAIRE = re.compile(r'<!--.*?-->', re.DOTALL)
ENTETE_MEMOIRE = "<!-- Claude's notes (persistent memory): erased when the mode is turned off. -->"
MAX_INSTRUCTIONS = 4000
MAX_NOTE = 300
MAX_MEMOIRE = 4000

GABARIT = """<!--
Standing instructions for Claude (optional): write them below this comment, one per line.
They are added to every task ({normal} or {consigne}).
The instruction typed in the small bar takes priority over this file.
Comments like this one are ignored. You can also drop courses, PDFs or assignments
in this folder: Claude will read them if needed.

Examples:
I'm a BTS SIO student, SISR track. Cisco hardware, Packet Tracer 8.
For quizzes: tick the answers and click Next, but never click "Finish exam".
Always answer in French.

Keep the dashed line below. What you write above it is yours: it is never changed.
Below it, Claude writes its notes while "Persistent memory" is checked in the icon menu;
they are erased when you uncheck it.
-->



""" + SEPARATEUR + '\n' + ENTETE_MEMOIRE + '\n'


def active(fichier_etat):
    """True if persistent memory is switched on (data/memory.txt contains "on")."""
    return lire(fichier_etat).strip().lower() == 'on'


def lire(chemin):
    try:
        with open(chemin, encoding='utf-8-sig', errors='replace') as f:
            return f.read()
    except OSError:
        return ''


def ecrire(chemin, texte):
    with open(chemin, 'w', encoding='utf-8') as f:
        f.write(texte)


def decouper(texte):
    """(user part, memory part) as written; memory part is None if there is no separator."""
    m = LIGNE_SEPARATEUR.search(texte)
    if not m:
        return texte, None
    return texte[:m.start()], texte[m.end():]


def nettoyer(texte):
    """Text without comments or empty lines."""
    lignes = (l.rstrip() for l in COMMENTAIRE.sub('', texte).splitlines())
    return '\n'.join(l for l in lignes if l.strip())


def _avec_section_vide(utilisateur):
    return utilisateur.rstrip() + '\n\n' + SEPARATEUR + '\n' + ENTETE_MEMOIRE + '\n'


def instructions(chemin):
    """The user's instructions (above the separator), cleaned, 4000 characters at most."""
    return nettoyer(decouper(lire(chemin))[0])[:MAX_INSTRUCTIONS]


def notes(chemin):
    """Claude's notes (below the separator), cleaned."""
    section = decouper(lire(chemin))[1]
    return nettoyer(section)[:MAX_MEMOIRE] if section else ''


def preparer(chemin):
    """Adds the separator at the end of the file if it is missing (the user's text is kept)."""
    texte = lire(chemin)
    if decouper(texte)[1] is None:
        ecrire(chemin, _avec_section_vide(texte))


def vider(chemin):
    """Erases Claude's notes. Everything above the separator stays as it is. True if notes were erased."""
    texte = lire(chemin)
    utilisateur, section = decouper(texte)
    if section is None or not nettoyer(section):
        return False
    ecrire(chemin, _avec_section_vide(utilisateur))
    return True


def ajouter(chemin, note):
    """Adds a note at the end of the memory section. ValueError if it is empty or too long."""
    note = ' '.join(note.split())
    if not note:
        raise ValueError('Usage: memoire "note"')
    if len(note) > MAX_NOTE:
        raise ValueError('Note too long (%d characters, %d max): keep one short fact per note.' % (len(note), MAX_NOTE))
    if not os.path.exists(chemin):
        raise ValueError('%s not found.' % chemin)
    preparer(chemin)
    texte = lire(chemin)
    if len(nettoyer(decouper(texte)[1])) + len(note) + 3 > MAX_MEMOIRE:
        raise ValueError('Memory is full (%d characters): the user must turn persistent memory off and on '
                         'again to empty it. Do not save more notes.' % MAX_MEMOIRE)
    ecrire(chemin, texte.rstrip() + '\n- ' + note + '\n')


def migrer(ancien, nouveau):
    """instructions.txt (older versions) -> instructions.md: lines starting with # become comments."""
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
    ecrire(nouveau, _avec_section_vide('\n'.join(lignes)))
    os.remove(ancien)
    return True
