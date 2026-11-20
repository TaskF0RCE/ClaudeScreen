"""Computer control actions for Claude (equivalent of the Windows actions.ps1).

Coordinates are in screenshot pixels (see screen.json in the task folder).
Claude goes through mcp.py (the MCP server), which calls main() once per action.
"""
from __future__ import annotations

import glob
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import humain  # noqa: E402
import natif  # noqa: E402

USAGE = """Actions:
  capture | zoom X Y W H | clic X Y | doubleclic X Y | clicdroit X Y | survol X Y
  glisser X1 Y1 X2 Y2 | relier X1 Y1 X2 Y2 | defiler X Y N | ecrire "text" | remplacer "text" | ecrire-fichier PATH
  touche COMBO | attendre MS | corbeille PATH | page-pdf PATH N
"""

# Path of the image made by the last action (capture, zoom, page-pdf), otherwise None. Read by mcp.py.
IMAGE = None


def dans(chemin, dossier):
    """Is chemin the folder itself or inside it? (symlinks and ".." resolved)"""
    a, b = os.path.realpath(chemin), os.path.realpath(dossier)
    if sys.platform == 'darwin':  # case-insensitive disk by default on macOS
        a, b = a.lower(), b.lower()
    return a == b or a.startswith(b.rstrip(os.sep) + os.sep)


def main(argv):
    global IMAGE
    IMAGE = None
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
        IMAGE = png
        print('Screenshot: %s (%dx%d px)' % (png, ecran['largeur'], ecran['hauteur']))
    elif action == 'zoom':
        # Enlarges an area to read small details (read-only).
        png = suivant('zoom')
        natif.capturer(png, X(nombre(0)), Y(nombre(1)), nombre(2) * e, nombre(3) * e, None, cote_max=1600)
        IMAGE = png
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
    elif action == 'relier':
        # relier X1 Y1 X2 Y2: click on point 1, then on point 2. Links two items in tools where a link is made
        # with two clicks (Packet Tracer or GNS3 cable, the cable tool being selected). The 4 numbers are checked
        # first, so a bad argument never leaves a link half done. Smooth mode applies, like for any click.
        x1, y1, x2, y2 = X(nombre(0)), Y(nombre(1)), X(nombre(2)), Y(nombre(3))
        natif.clic(x1, y1, doux=doux)
        time.sleep(0.4)  # the first click must be taken in before the second one
        natif.clic(x2, y2, doux=doux)
        print('OK')
    elif action == 'defiler':
        natif.molette(X(nombre(0)), Y(nombre(1)), int(nombre(2)), doux)
        print('OK')
    elif action == 'ecrire':
        natif.taper(' '.join(valeurs), doux)
        print('OK')
    elif action == 'remplacer':
        # Replaces what the focused field holds: select all, then type over the selection.
        natif.combo(['cmd' if natif.MAC else 'ctrl', 'a'])
        time.sleep(0.08)
        natif.taper(' '.join(valeurs), doux)
        print('OK')
    elif action == 'ecrire-fichier':
        chemin = os.path.abspath(' '.join(valeurs))
        # Only files of the work folder or of the task: a private file (~/.ssh, history...) is never typed.
        lisibles = [d for d in os.environ.get('ECRAN_LECTURE', '').split(os.pathsep) if d]
        if lisibles and not any(dans(chemin, d) for d in lisibles):
            raise SystemExit('Refused: %s is outside the work folder. Write the text to a file in the current '
                             'folder first, then type that file.' % chemin)
        with open(chemin, encoding='utf-8-sig') as f:
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
        if ctx and (dans(chemin, ctx) or dans(ctx, chemin)):
            raise SystemExit('Refused: %s is read-only (the user\'s documents).' % ctx)
        # Only what is inside the work folder (never the folder itself): the rest of the computer is the user's.
        travail = os.environ.get('ECRAN_TRAVAIL')
        if travail and (not dans(chemin, travail) or dans(travail, chemin)):
            raise SystemExit('Refused: only files of the work folder (%s) can be sent to the trash.' % travail)
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
        IMAGE = png
        print('Page %d/%d: %s' % (numero, pages, png))
    else:
        raise SystemExit('Unknown action: %s\n%s' % (action, USAGE))


if __name__ == '__main__':
    main(sys.argv[1:])
