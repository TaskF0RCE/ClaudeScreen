"""Smooth mode: mouse moves and typing that look like a human (equivalent of the Smooth part of natif.cs).

Switched on and off from the icon menu ("Smooth mode"); the choice is kept in data/smooth.txt
and read by pc.py at every action, so it applies right away, even during a task.

  - Mouse: curved path (cubic Bézier bent a little to one side), speeds up then slows down
    (minimum-jerk profile), duration that grows with the distance (Fitts' law): ~0.2 s for a
    short hop, ~0.75 s across a large screen. A short pause before clicking.
  - Typing: one key at a time, ~9 characters per second with irregular gaps, a longer pause
    after a space, punctuation and Enter. Long texts are typed faster so that one action never
    takes more than ~45 s (Claude Code stops a command after 2 minutes).
"""
from __future__ import annotations

import math
import os
import random
import time

FICHIER = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'data', 'smooth.txt')
FREQUENCE = 0.008       # one mouse position every 8 ms (~120 Hz)
FRAPPE_MAX = 45.0       # seconds: longer texts are typed faster
FRAPPE_MIN = 0.012      # but never faster than one key every 12 ms
PONCTUATION = '.,;:!?'

_hasard = random.SystemRandom()


def actif():
    """True if smooth mode is switched on (data/smooth.txt contains "on")."""
    try:
        with open(FICHIER, encoding='utf-8') as f:
            return f.read().strip().lower() == 'on'
    except OSError:
        return False


def entre(a, b):
    return _hasard.uniform(a, b)


def pause_avant_clic():
    time.sleep(entre(0.06, 0.14))


def duree_trajet(distance):
    """Movement time in seconds (Fitts' law, target ~20 px wide), with a little variation."""
    t = 0.12 + 0.11 * math.log2(1 + distance / 20.0)
    return min(1.1, max(0.18, t)) * entre(0.9, 1.1)


def trajet(depart, arrivee, lenteur=1.0, courbe=1.0):
    """Function t (0..1 of the time) -> (x, y), and the total duration in seconds.

    lenteur > 1 slows the movement down (dragging); courbe < 1 makes the path straighter.
    """
    x0, y0 = depart
    x1, y1 = arrivee
    dx, dy = x1 - x0, y1 - y0
    d = math.hypot(dx, dy)
    if d < 3:
        return (lambda t: (x1, y1)), 0.0
    nx, ny = -dy / d, dx / d                      # unit vector perpendicular to the line
    ecart = min(120.0, d * entre(0.05, 0.18)) * courbe * _hasard.choice((-1, 1))
    a, b = entre(0.2, 0.35), entre(0.65, 0.8)     # where the control points sit along the line
    f1, f2 = entre(0.6, 1.0), entre(0.3, 0.7)     # how far each one is pushed to the side
    c1 = (x0 + dx * a + nx * ecart * f1, y0 + dy * a + ny * ecart * f1)
    c2 = (x0 + dx * b + nx * ecart * f2, y0 + dy * b + ny * ecart * f2)

    def point(t):
        s = t * t * t * (10 - 15 * t + 6 * t * t)  # minimum jerk: smooth start and stop
        u = 1 - s
        x = u * u * u * x0 + 3 * u * u * s * c1[0] + 3 * u * s * s * c2[0] + s * s * s * x1
        y = u * u * u * y0 + 3 * u * u * s * c1[1] + 3 * u * s * s * c2[1] + s * s * s * y1
        return x, y

    return point, duree_trajet(d) * lenteur


def glisser(depart, arrivee, poser, lenteur=1.0, courbe=1.0):
    """Moves the mouse from depart to arrivee by calling poser(x, y) about every 8 ms.

    The position is computed from the elapsed time, so a slow system skips points
    instead of slowing the movement down.
    """
    point, duree = trajet(depart, arrivee, lenteur, courbe)
    debut = time.monotonic()
    while duree > 0:
        t = (time.monotonic() - debut) / duree
        if t >= 1:
            break
        poser(*point(t))
        time.sleep(FREQUENCE)
    poser(*arrivee)


def delais_frappe(texte):
    """Pause after each character of texte, in seconds (same length as texte)."""
    delais = []
    for c in texte:
        if c == '\r':
            delais.append(0.0)
            continue
        d = entre(0.07, 0.15)
        if c.isupper():
            d += 0.03                       # Shift
        if c == ' ':
            d += entre(0.02, 0.08)          # between two words
        elif c in PONCTUATION:
            d += entre(0.12, 0.25)          # end of a phrase
        elif c == '\n':
            d += entre(0.25, 0.45)          # Enter: also gives a terminal (Cisco CLI...) time to answer
        delais.append(d)
    total = sum(delais)
    if total > FRAPPE_MAX:
        facteur = FRAPPE_MAX / total
        delais = [max(FRAPPE_MIN, d * facteur) if d else 0.0 for d in delais]
    return delais
