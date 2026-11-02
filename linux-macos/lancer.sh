#!/usr/bin/env bash
# Lance ClaudeScreen en arrière-plan (seulement l'icône dans la barre des menus / zone de notifications).
#   ./lancer.sh               lance l'appli
#   ./lancer.sh declencher    comme Ctrl+Alt+C        (pour un raccourci clavier du bureau)
#   ./lancer.sh consigne      comme Ctrl+Alt+Shift+C
#   ./lancer.sh arreter | resultat | quitter | etat | diagnostic
DIR="$(cd "$(dirname "$0")" && pwd)"
PY="$DIR/donnees/.venv/bin/python3"
export PYTHONPYCACHEPREFIX="$DIR/donnees/cache"
if [ ! -x "$PY" ]; then
    echo "Environnement Python absent : lance d'abord ./installer.sh" >&2
    exit 1
fi
if [ $# -gt 0 ]; then
    exec "$PY" "$DIR/claude_screen.py" "$@"
fi
mkdir -p "$DIR/donnees"
nohup "$PY" "$DIR/claude_screen.py" >/dev/null 2>>"$DIR/donnees/journal.txt" &
disown 2>/dev/null || true
