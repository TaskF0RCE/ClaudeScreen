"""MCP server (stdio) that gives Claude the computer control actions through one tool, "pc".

Equivalent of the Windows outils/mcp.ps1. Claude Code starts it once per task and keeps it open: an
action does not start a new Python, several actions go in one call, and the screenshot comes back in
the answer instead of being read in a second step.
Protocol: one JSON-RPC message per line on stdin/stdout (Model Context Protocol). Nothing else may be
written to stdout. No network port is opened. The actions themselves are in pc.py.
"""
from __future__ import annotations

import base64
import contextlib
import io
import json
import os
import sys
import time

# The real stdout is kept for the protocol only: whatever else prints (a module, a program started by
# an action) goes to stderr instead of breaking the JSON stream.
SORTIE = os.fdopen(os.dup(1), 'w', encoding='utf-8', newline='\n')
try:
    os.dup2(2, 1)
except OSError:
    pass
sys.stdout = sys.stderr

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import natif  # noqa: E402
import pc  # noqa: E402

MAX_ACTIONS = 40
# Actions whose argument is one text or one path: everything after the action name, spaces included.
ACTIONS_TEXTE = ('ecrire', 'remplacer', 'ecrire-fichier', 'corbeille')
# Actions that can bring another window to the front (the active window is read again after them).
ACTIONS_FENETRE = ('clic', 'doubleclic', 'clicdroit', 'relier', 'glisser', 'touche')
OUTILS = [{
    'name': 'pc',
    'description': "Controls the user's computer with the mouse and keyboard. Runs the given actions in order and "
                   'stops at the first error. By default the result ends with a new screenshot taken after the '
                   'last action.',
    'inputSchema': {
        'type': 'object',
        'properties': {
            'actions': {
                'type': 'array', 'items': {'type': 'string'}, 'minItems': 1, 'maxItems': MAX_ACTIONS,
                'description': 'Actions to run in order, one per string, written as listed in your instructions, '
                               'e.g. ["clic 412 300", "remplacer Paris", "touche enter"].'},
            'capture': {
                'type': 'boolean',
                'description': 'true (default): take a screenshot after the last action and return it. '
                               'false: no screenshot.'},
        },
        'required': ['actions'],
    },
}]

# The last "clic", to keep two separate clicks on one spot from being read as a double-click.
_dernier_clic = None  # (x, y, time)


def image(png):
    """Image file -> MCP image block. JPEG when Pillow is there (about 5 times lighter than the PNG)."""
    try:
        from PIL import Image
        tampon = io.BytesIO()
        with Image.open(png) as img:
            img.convert('RGB').save(tampon, 'JPEG', quality=90)
        return {'type': 'image', 'data': base64.b64encode(tampon.getvalue()).decode('ascii'), 'mimeType': 'image/jpeg'}
    except ImportError:
        with open(png, 'rb') as f:
            return {'type': 'image', 'data': base64.b64encode(f.read()).decode('ascii'), 'mimeType': 'image/png'}


def decouper(ligne):
    """"clic 10 20" -> (action, arguments), for pc.main."""
    morceaux = ligne.strip().split(None, 1)
    nom = morceaux[0]
    reste = morceaux[1].strip() if len(morceaux) > 1 else ''
    if nom.lower() in ACTIONS_TEXTE:
        # Quotes around the whole text are optional here (there is no shell): remove one pair.
        if len(reste) >= 2 and reste[0] == '"' and reste[-1] == '"':
            reste = reste[1:-1]
        return nom, [reste]
    return nom, reste.split()


def fenetre():
    """Program and title of the window that has the keyboard, or '' if it cannot be read."""
    try:
        f = natif.fenetre_active()
        return '%s - "%s"' % (f[0], f[1]) if f[0] or f[1] else ''
    except Exception:
        return ''


def _position_clic(action, valeurs):
    """(x, y) of a "clic" action, None for anything else."""
    if action != 'clic':
        return None
    try:
        return float(valeurs[0].replace(',', '.')), float(valeurs[1].replace(',', '.'))
    except (IndexError, ValueError):
        return None


def executer(nom, valeurs):
    """Runs one action. Returns (text, path of the image it made or None). Raises RuntimeError on a bad action."""
    global _dernier_clic
    action = nom.lower()
    position = _position_clic(action, valeurs)
    if position and _dernier_clic and abs(position[0] - _dernier_clic[0]) <= 8 and abs(position[1] - _dernier_clic[1]) <= 8:
        # Two "clic" actions on the same spot, one right after the other, are two clicks: the system would
        # turn them into a double-click (which opens or closes something else), so the second one waits.
        reste = 0.6 - (time.monotonic() - _dernier_clic[2])
        if reste > 0:
            time.sleep(reste)
    tampon = io.StringIO()
    try:
        with contextlib.redirect_stdout(tampon):
            pc.main([nom] + valeurs)
    except SystemExit as ex:  # pc.py stops this way on a bad action or argument
        raise RuntimeError(str(ex.code).strip() if ex.code not in (None, 0) else 'stopped')
    if position:
        _dernier_clic = (position[0], position[1], time.monotonic())
    if action in ('clic', 'doubleclic', 'clicdroit'):
        time.sleep(0.15)  # lets a menu, a list or a window open before the next action of the same call
    return tampon.getvalue().strip(), pc.IMAGE


def appeler(arguments):
    """tools/call: runs the actions and returns the result (content + isError)."""
    images, lignes, erreur = [], [], False
    actions = [str(a) for a in (arguments.get('actions') or []) if str(a).strip()]
    capture = arguments.get('capture')
    capture = True if capture is None else bool(capture)
    derniere = ''
    if not actions:
        erreur = True
        lignes.append('ERROR: "actions" is empty.')
    elif len(actions) > MAX_ACTIONS:
        erreur = True
        lignes.append('ERROR: %d actions, %d at most per call. Nothing was run.' % (len(actions), MAX_ACTIONS))
    else:
        avant = fenetre()
        for n, ligne in enumerate(actions, 1):
            nom, valeurs = decouper(ligne)
            try:
                resultat, png = executer(nom, valeurs)
                derniere = nom.lower()
                if png:
                    # The image itself follows: the path is of no use to Claude.
                    lignes.append('%d. %s: image below%s' % (
                        n, nom, ' (read-only, do not use its coordinates to click)' if derniere == 'zoom' else ''))
                    images.append(image(png))
                    continue
                if derniere in ACTIONS_FENETRE:
                    # Another window came to the front during this action: said on its line, so that Claude sees
                    # at which step it happened (the actions after it may have landed in the wrong window).
                    maintenant = fenetre()
                    if maintenant and avant and maintenant != avant:
                        resultat = '%s (the active window is now: %s)' % (resultat, maintenant)
                    avant = maintenant or avant
                lignes.append('%d. %s: %s' % (n, nom, resultat))
            except Exception as ex:
                erreur = True
                lignes.append('%d. %s: ERROR: %s' % (n, nom, ex))
                if n < len(actions):
                    lignes.append('The %d action(s) after it were not run.' % (len(actions) - n))
                break
        if capture and derniere != 'capture':
            try:
                time.sleep(0.35)  # lets the screen react to the last action
                resultat, png = executer('capture', [])
                lignes.append('Screenshot after the last action: below (%s).' % resultat.rsplit('(', 1)[-1].rstrip(')'))
                images.append(image(png))
            except Exception as ex:
                lignes.append('Screenshot failed: %s' % ex)
        # The window that has the keyboard now: lets Claude notice that another one came to the front.
        f = fenetre()
        if f:
            lignes.append('Active window: %s' % f)
    return {'content': [{'type': 'text', 'text': '\n'.join(lignes)}] + images, 'isError': erreur}


def repondre(ident, resultat=None, echec=None):
    message = {'jsonrpc': '2.0', 'id': ident}
    if echec:
        message['error'] = echec
    else:
        message['result'] = resultat
    SORTIE.write(json.dumps(message, ensure_ascii=False) + '\n')
    SORTIE.flush()


def serveur():
    for brut in sys.stdin.buffer:
        ligne = brut.decode('utf-8', errors='replace').strip()
        if not ligne:
            continue
        try:
            requete = json.loads(ligne)
        except ValueError:
            continue
        if not isinstance(requete, dict) or requete.get('id') is None:
            continue  # notification (initialized, cancelled...): no answer
        ident, methode, params = requete['id'], requete.get('method'), requete.get('params') or {}
        try:
            if methode == 'initialize':
                # Tells the app that Claude Code reached this server (the app warns the user otherwise).
                try:
                    with open(os.path.join(os.environ.get('ECRAN_RUN', ''), 'mcp-started.txt'), 'w'):
                        pass
                except OSError:
                    pass
                repondre(ident, {'protocolVersion': str(params.get('protocolVersion') or '2024-11-05'),
                                 'capabilities': {'tools': {}},
                                 'serverInfo': {'name': 'claudescreen-pc', 'version': '1'}})
            elif methode == 'ping':
                repondre(ident, {})
            elif methode == 'tools/list':
                repondre(ident, {'tools': OUTILS})
            elif methode == 'tools/call':
                if params.get('name') != 'pc':
                    repondre(ident, echec={'code': -32602, 'message': 'Unknown tool'})
                else:
                    repondre(ident, appeler(params.get('arguments') or {}))
            else:
                repondre(ident, echec={'code': -32601, 'message': 'Method not found'})
        except Exception as ex:
            repondre(ident, echec={'code': -32603, 'message': str(ex)})


if __name__ == '__main__':
    serveur()
