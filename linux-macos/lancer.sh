#!/usr/bin/env bash
# Starts ClaudeEcran in the background (only the icon in the menu bar / notification area).
#   ./lancer.sh               starts the app
#   ./lancer.sh declencher    same as Ctrl+Alt+C        (for a desktop keyboard shortcut)
#   ./lancer.sh consigne      same as Ctrl+Alt+Shift+C
#   ./lancer.sh arreter | resultat | quitter | etat | diagnostic
DIR="$(cd "$(dirname "$0")" && pwd)"
PY="$DIR/donnees/.venv/bin/python3"
export PYTHONPYCACHEPREFIX="$DIR/donnees/cache"
if [ ! -x "$PY" ]; then
    echo "Python environment missing: run ./installer.sh first" >&2
    exit 1
fi
if [ $# -gt 0 ]; then
    exec "$PY" "$DIR/claude_ecran.py" "$@"
fi
mkdir -p "$DIR/donnees"
nohup "$PY" "$DIR/claude_ecran.py" >/dev/null 2>>"$DIR/donnees/journal.txt" &
disown 2>/dev/null || true
