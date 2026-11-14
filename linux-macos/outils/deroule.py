"""What Claude said and did during a task, read from the stream that Claude Code writes while it works
(responses/task.jsonl, one JSON event per line: --output-format stream-json).

Used to show the steps of a task: while it runs, when it was stopped, and in the History menu.
Same logic as the Windows outils/deroule.ps1.
"""
from __future__ import annotations

import json
import os
import re

MAX_ETAPES = 80   # only the last steps are kept
MAX_TEXTE = 400   # characters per step
MAX_LIGNE = 200000
LIGNE_MEMOIRE = re.compile(r'^\s*(?:[-*]\s*)?\**MEMORY:')


def _limiter(texte, maximum):
    texte = ' '.join(str(texte).split())
    return texte[:maximum - 3] + '...' if len(texte) > maximum else texte


def _outil(bloc):
    """One tool call as a short line, or None for the calls that say nothing to the user (reading, searching)."""
    nom = str(bloc.get('name') or '')
    entree = bloc.get('input') or {}
    if nom.startswith('mcp__pc__'):
        actions = [str(a).strip() for a in (entree.get('actions') or []) if str(a).strip()]
        return '  > ' + _limiter(', '.join(actions), 160) if actions else None
    if nom in ('Write', 'Edit', 'MultiEdit', 'NotebookEdit'):
        fichier = entree.get('file_path') or entree.get('notebook_path')
        return '  > file written: ' + os.path.basename(str(fichier)) if fichier else None
    if nom in ('PowerShell', 'Bash'):
        return '  > command: ' + _limiter(entree.get('command') or '', 160)
    return None


def lire(chemin):
    """Reads the stream of a task. Returns (steps, final answer, number of earlier steps left out).

    The final answer is None while the task is not finished or when it was stopped.
    The file may still be being written: a half-written line is skipped.
    """
    etapes, resultat = [], None
    try:
        f = open(chemin, encoding='utf-8', errors='replace')
    except OSError:
        return [], None, 0
    with f:
        for ligne in f:
            # The results of the tools hold the screenshots (hundreds of KB per line): never parsed.
            if len(ligne) < 20 or len(ligne) > MAX_LIGNE or ligne.startswith(('{"type":"user"', '{"type":"system"', '{"type":"rate')):
                continue
            try:
                o = json.loads(ligne)
            except ValueError:
                continue
            if not isinstance(o, dict):
                continue
            if o.get('type') == 'result':
                if str(o.get('result') or '').strip():
                    resultat = str(o['result']).strip()
                continue
            if o.get('type') != 'assistant':
                continue
            for bloc in (o.get('message') or {}).get('content') or []:
                etape = None
                if not isinstance(bloc, dict):
                    continue
                if bloc.get('type') == 'text':
                    # The "MEMORY: ..." lines are for the app, not for the user.
                    texte = '\n'.join(l for l in str(bloc.get('text') or '').splitlines() if not LIGNE_MEMOIRE.match(l))
                    if texte.strip():
                        etape = _limiter(texte, MAX_TEXTE)
                elif bloc.get('type') == 'tool_use':
                    etape = _outil(bloc)
                if etape and (not etapes or etapes[-1] != etape):
                    etapes.append(etape)
    # The last thing Claude says is its final answer: shown as the result, not as a step.
    if resultat and etapes and not etapes[-1].startswith('  > '):
        fin, debut = etapes[-1].rstrip('.'), _limiter(resultat, MAX_TEXTE).rstrip('.')
        if debut.startswith(fin) or fin.startswith(debut):
            etapes.pop()
    omises = max(0, len(etapes) - MAX_ETAPES)
    return etapes[omises:], resultat, omises


def texte(etapes, omises=0):
    """The steps as a text, one per line ('' when there is none)."""
    if not etapes:
        return ''
    return ('(... %d earlier steps not shown)\n' % omises if omises else '') + '\n'.join(etapes)


def compresser(chemin):
    """Once a task is over, the stream is only kept for its steps: the lines that hold the screenshots are
    dropped (a long task would otherwise leave tens of MB behind)."""
    try:
        with open(chemin, encoding='utf-8', errors='replace') as f:
            garde = [l for l in f if len(l) <= MAX_LIGNE and not l.startswith('{"type":"user"')]
        with open(chemin, 'w', encoding='utf-8') as f:
            f.writelines(garde)
    except OSError:
        pass
