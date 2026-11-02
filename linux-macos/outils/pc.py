"""Computer control for Claude (equivalent of pc.ps1).

Coordinates are in screenshot pixels (see ecran.json in the task folder).
Claude calls it through the small donnees/pc script generated when the app starts.
"""
from __future__ import annotations

import glob
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import natif  # noqa: E402

USAGE = """Actions:
  capture | zoom X Y W H | clic X Y | doubleclic X Y | clicdroit X Y | survol X Y
  glisser X1 Y1 X2 Y2 | defiler X Y N | ecrire "text" | ecrire-fichier PATH
  touche COMBO | attendre MS | corbeille PATH"""


def main(argv):
    if not argv:
        raise SystemExit(USAGE)
    action = argv[0].lower()
    valeurs = argv[1:]

    run = os.environ.get('ECRAN_RUN')
    if not run:
        raise SystemExit('ECRAN_RUN is not set: this script must be started by ClaudeEcran.')
    with open(os.path.join(run, 'ecran.json'), encoding='utf-8') as f:
        ecran = json.load(f)
    e = ecran['echelle']

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
        n = len(glob.glob(os.path.join(run, prefixe + '-*.png'))) + 1
        return os.path.join(run, '%s-%02d.png' % (prefixe, n))

    if action == 'capture':
        png = suivant('capture')
        natif.capturer(png, ecran['gauche'], ecran['haut'], ecran['largeurEcran'], ecran['hauteurEcran'], e)
        print('Screenshot: %s (%dx%d px)' % (png, ecran['largeur'], ecran['hauteur']))
    elif action == 'zoom':
        # Enlarges an area to read small details (read-only).
        png = suivant('zoom')
        natif.capturer(png, X(nombre(0)), Y(nombre(1)), nombre(2) * e, nombre(3) * e, None, cote_max=1600)
        print('Zoom: %s (read-only, do not use its coordinates to click)' % png)
    elif action == 'clic':
        natif.clic(X(nombre(0)), Y(nombre(1)))
        print('OK')
    elif action == 'doubleclic':
        natif.clic(X(nombre(0)), Y(nombre(1)), nombre=2)
        print('OK')
    elif action == 'clicdroit':
        natif.clic(X(nombre(0)), Y(nombre(1)), droit=True)
        print('OK')
    elif action == 'survol':
        natif.deplacer(X(nombre(0)), Y(nombre(1)))
        print('OK')
    elif action == 'glisser':
        natif.glisser(X(nombre(0)), Y(nombre(1)), X(nombre(2)), Y(nombre(3)))
        print('OK')
    elif action == 'defiler':
        natif.molette(X(nombre(0)), Y(nombre(1)), int(nombre(2)))
        print('OK')
    elif action == 'ecrire':
        natif.taper(' '.join(valeurs))
        print('OK')
    elif action == 'ecrire-fichier':
        with open(' '.join(valeurs), encoding='utf-8-sig') as f:
            natif.taper(f.read())
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
        natif.corbeille(chemin)
        print('Sent to the trash: %s' % chemin)
    else:
        raise SystemExit('Unknown action: %s\n%s' % (action, USAGE))


if __name__ == '__main__':
    main(sys.argv[1:])
