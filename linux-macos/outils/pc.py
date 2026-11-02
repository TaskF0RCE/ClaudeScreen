"""Contrôle de l'ordinateur pour Claude (équivalent de pc.ps1).

Les coordonnées sont en pixels de la capture (voir ecran.json dans le dossier de la tâche).
Claude l'appelle via le petit script donnees/pc généré au démarrage de l'appli.
"""
from __future__ import annotations

import glob
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import natif  # noqa: E402

USAGE = """Actions :
  capture | zoom X Y L H | clic X Y | doubleclic X Y | clicdroit X Y | survol X Y
  glisser X1 Y1 X2 Y2 | defiler X Y N | ecrire "texte" | ecrire-fichier CHEMIN
  touche COMBO | attendre MS | corbeille CHEMIN"""


def main(argv):
    if not argv:
        raise SystemExit(USAGE)
    action = argv[0].lower()
    valeurs = argv[1:]

    run = os.environ.get('ECRAN_RUN')
    if not run:
        raise SystemExit('ECRAN_RUN non défini : ce script doit être lancé par ClaudeEcran.')
    with open(os.path.join(run, 'ecran.json'), encoding='utf-8') as f:
        ecran = json.load(f)
    e = ecran['echelle']

    def nombre(i):
        if len(valeurs) <= i:
            raise SystemExit("Argument %d manquant pour '%s'." % (i + 1, action))
        try:
            return float(valeurs[i].replace(',', '.'))
        except ValueError:
            raise SystemExit("Argument %d invalide pour '%s' : %s" % (i + 1, action, valeurs[i]))

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
        print('Capture : %s (%dx%d px)' % (png, ecran['largeur'], ecran['hauteur']))
    elif action == 'zoom':
        # Agrandit une zone pour lire les petits détails (lecture seule).
        png = suivant('zoom')
        natif.capturer(png, X(nombre(0)), Y(nombre(1)), nombre(2) * e, nombre(3) * e, None, cote_max=1600)
        print('Zoom : %s (lecture seule, ne pas utiliser ses coordonnées pour cliquer)' % png)
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
            raise SystemExit('Introuvable : %s' % chemin)
        # Le dossier de contexte (System-Context) est en lecture seule : ni lui, ni son contenu,
        # ni un dossier qui le contient.
        ctx = os.environ.get('ECRAN_CONTEXTE')
        if ctx:
            a, b = os.path.realpath(chemin), os.path.realpath(ctx)
            if sys.platform == 'darwin':  # disque insensible à la casse par défaut sur macOS
                a, b = a.lower(), b.lower()
            if a == b or a.startswith(b.rstrip(os.sep) + os.sep) or b.startswith(a.rstrip(os.sep) + os.sep):
                raise SystemExit('Refusé : %s est en lecture seule (documents de l\'utilisateur).' % ctx)
        natif.corbeille(chemin)
        print('Mis à la corbeille : %s' % chemin)
    else:
        raise SystemExit('Action inconnue : %s\n%s' % (action, USAGE))


if __name__ == '__main__':
    main(sys.argv[1:])
