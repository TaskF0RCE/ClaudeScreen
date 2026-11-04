"""Computer control for Claude (equivalent of pc.ps1).

Coordinates are in screenshot pixels (see screen.json in the task folder).
Claude calls it through the small data/pc script generated when the app starts.
"""
from __future__ import annotations

import glob
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import humain  # noqa: E402
import memoire  # noqa: E402
import natif  # noqa: E402

MEMOIRE = os.path.join(os.path.dirname(humain.FICHIER), 'memory.txt')  # persistent memory: on or off

USAGE = """Actions:
  capture | zoom X Y W H | clic X Y | doubleclic X Y | clicdroit X Y | survol X Y
  glisser X1 Y1 X2 Y2 | defiler X Y N | ecrire "text" | ecrire-fichier PATH
  touche COMBO | attendre MS | corbeille PATH | page-pdf PATH N
  memoire "note"
"""


def main(argv):
    if not argv:
        raise SystemExit(USAGE)
    action = argv[0].lower()
    valeurs = argv[1:]

    run = os.environ.get('ECRAN_RUN')
    if not run:
        raise SystemExit('ECRAN_RUN is not set: this script must be started by ClaudeScreen.')
    with open(os.path.join(run, 'screen.json'), encoding='utf-8') as f:
        ecran = json.load(f)
    e = ecran['echelle']
    doux = humain.actif()  # smooth mode (icon menu), read at every action

    def nombre(i):
        if len(valeurs) <= i:
            raise SystemExit("Missing argument %d for '%s'." % (i + 1, action))
        try:
            return float(valeurs[i].replace(',', '.'))
        except ValueError:
            raise SystemExit("Invalid argument %d for '%s': %s" % (i + 1, action, valeurs[i]))

    def X(x):
        return ecran['gauche'] + x * e

    def Y(y):
        return ecran['haut'] + y * e

    def suivant(prefixe):
        images = os.path.join(run, 'images')  # every image of the task: screenshots, zooms, PDF pages
        os.makedirs(images, exist_ok=True)
        n = len(glob.glob(os.path.join(images, prefixe + '-*.png'))) + 1
        return os.path.join(images, '%s-%02d.png' % (prefixe, n))

    if action == 'capture':
        png = suivant('screenshot')
        natif.capturer(png, ecran['gauche'], ecran['haut'], ecran['largeurEcran'], ecran['hauteurEcran'], e)
        print('Screenshot: %s (%dx%d px)' % (png, ecran['largeur'], ecran['hauteur']))
    elif action == 'zoom':
        # Enlarges an area to read small details (read-only).
        png = suivant('zoom')
        natif.capturer(png, X(nombre(0)), Y(nombre(1)), nombre(2) * e, nombre(3) * e, None, cote_max=1600)
        print('Zoom: %s (read-only, do not use its coordinates to click)' % png)
    elif action == 'clic':
        natif.clic(X(nombre(0)), Y(nombre(1)), doux=doux)
        print('OK')
    elif action == 'doubleclic':
        natif.clic(X(nombre(0)), Y(nombre(1)), nombre=2, doux=doux)
        print('OK')
    elif action == 'clicdroit':
        natif.clic(X(nombre(0)), Y(nombre(1)), droit=True, doux=doux)
        print('OK')
    elif action == 'survol':
        natif.deplacer(X(nombre(0)), Y(nombre(1)), doux)
        print('OK')
    elif action == 'glisser':
        natif.glisser(X(nombre(0)), Y(nombre(1)), X(nombre(2)), Y(nombre(3)), doux)
        print('OK')
    elif action == 'defiler':
        natif.molette(X(nombre(0)), Y(nombre(1)), int(nombre(2)), doux)
        print('OK')
    elif action == 'ecrire':
        natif.taper(' '.join(valeurs), doux)
        print('OK')
    elif action == 'ecrire-fichier':
        with open(' '.join(valeurs), encoding='utf-8-sig') as f:
            natif.taper(f.read(), doux)
        print('OK')
    elif action == 'touche':
        try:
            natif.combo(''.join(valeurs).split('+'))
        except ValueError as ex:
            raise SystemExit(str(ex))
        print('OK')
    elif action == 'attendre':
        time.sleep(max(0.0, nombre(0)) / 1000.0)
        print('OK')
    elif action == 'corbeille':
        chemin = os.path.abspath(' '.join(valeurs))
        if not os.path.exists(chemin):
            raise SystemExit('Not found: %s' % chemin)
        # The context folder (System-Context) is read-only: neither the folder, nor its contents,
        # nor a folder that contains it.
        ctx = os.environ.get('ECRAN_CONTEXTE')
        if ctx:
            a, b = os.path.realpath(chemin), os.path.realpath(ctx)
            if sys.platform == 'darwin':  # case-insensitive disk by default on macOS
                a, b = a.lower(), b.lower()
            if a == b or a.startswith(b.rstrip(os.sep) + os.sep) or b.startswith(a.rstrip(os.sep) + os.sep):
                raise SystemExit('Refused: %s is read-only (the user\'s documents).' % ctx)
        natif.corbeille(chemin)
        print('Sent to the trash: %s' % chemin)
    elif action == 'page-pdf':
        # page-pdf PATH N: one PDF page as an image (read-only; the path may contain spaces).
        if len(valeurs) < 2:
            raise SystemExit('Usage: page-pdf PATH N')
        chemin = os.path.abspath(' '.join(valeurs[:-1]))
        if not chemin.lower().endswith('.pdf') or not os.path.isfile(chemin):
            raise SystemExit('PDF not found: %s' % chemin)
        try:
            numero = int(valeurs[-1])
        except ValueError:
            raise SystemExit('Invalid page number: %s' % valeurs[-1])
        import pdf
        if not pdf.disponible():
            raise SystemExit('Missing pypdfium2 module: run ./installer.sh again.')
        png = suivant('pdf')
        try:
            pages = pdf.rendre_page(chemin, numero, png)
        except ValueError as ex:
            raise SystemExit(str(ex))
        print('Page %d/%d: %s (read it with Read)' % (numero, pages, png))
    elif action == 'memoire':
        # memoire "note": persistent memory (icon menu). Only appends below the separator of
        # System-Context/instructions.md: the user's part above it is never touched.
        if not memoire.active(MEMOIRE):
            raise SystemExit('Refused: persistent memory is off (the user turns it on in the icon menu).')
        ctx = os.environ.get('ECRAN_CONTEXTE')
        if not ctx:
            raise SystemExit('ECRAN_CONTEXTE is not set: this script must be started by ClaudeScreen.')
        try:
            memoire.ajouter(os.path.join(ctx, 'instructions.md'), ' '.join(valeurs))
        except (ValueError, OSError) as ex:
            raise SystemExit(str(ex))
        print('Note saved.')
    else:
        raise SystemExit('Unknown action: %s\n%s' % (action, USAGE))


if __name__ == '__main__':
    main(sys.argv[1:])
