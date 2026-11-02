#!/usr/bin/env bash
# Installe ClaudeScreen pour macOS ou Linux :
#   - environnement Python (donnees/.venv) et dépendances ;
#     tout ce qui est généré va dans donnees/, à part du programme ;
#   - macOS : l'appli ~/Applications/ClaudeScreen.app (+ ouverture à la connexion, en option) ;
#   - Linux : une entrée dans le menu des applications (+ démarrage automatique et
#     raccourcis clavier GNOME, en option).
#
# Options : --demarrage-auto | --sans-demarrage-auto
#           --raccourcis-gnome | --sans-raccourcis-gnome   (Linux, GNOME)
#           -y                (accepte les choix par défaut sans poser de question)
#           --desinstaller    (enlève l'appli, le démarrage auto et les raccourcis ; garde ce dossier)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"
DONNEES="$DIR/donnees"
VENV="$DONNEES/.venv"
PY="$VENV/bin/python3"
APP="$HOME/Applications/ClaudeScreen.app"
AGENT="$HOME/Library/LaunchAgents/local.claudescreen.plist"
BUREAU="$HOME/.local/share/applications/claude-screen.desktop"
AUTO="$HOME/.config/autostart/claude-screen.desktop"
SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
KPATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
export PYTHONPYCACHEPREFIX="$DONNEES/cache"  # pas de __pycache__ à côté du programme

DEMARRAGE=""
GNOME=""
OUI=0
DESINSTALLER=0
for arg in "$@"; do
    case "$arg" in
        --demarrage-auto) DEMARRAGE=1 ;;
        --sans-demarrage-auto) DEMARRAGE=0 ;;
        --raccourcis-gnome) GNOME=1 ;;
        --sans-raccourcis-gnome) GNOME=0 ;;
        -y|--oui) OUI=1 ;;
        --desinstaller) DESINSTALLER=1 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "Option inconnue : $arg" >&2; exit 2 ;;
    esac
done

info() { printf '\033[1m%s\033[0m\n' "$*"; }
avert() { printf '\033[33m! %s\033[0m\n' "$*"; }

# demander "question" défaut(1/0) -> 1 ou 0
demander() {
    local question="$1" defaut="$2" rep
    if [ "$OUI" = 1 ] || [ ! -t 0 ]; then echo "$defaut"; return; fi
    local choix="[O/n]"; [ "$defaut" = 0 ] && choix="[o/N]"
    read -r -p "$question $choix " rep </dev/tty || rep=""
    case "$rep" in
        [oOyY]*) echo 1 ;;
        [nN]*) echo 0 ;;
        *) echo "$defaut" ;;
    esac
}

# Ajoute (+) ou retire (-) nos deux chemins de la liste GNOME des raccourcis personnalisés.
liste_gnome() {
    python3 - "$1" "$(gsettings get "$SCHEMA" custom-keybindings)" "$KPATH" <<'EOF'
import ast, sys
op, actuelle, base = sys.argv[1], sys.argv[2], sys.argv[3]
actuelle = actuelle.replace('@as ', '')
liste = list(ast.literal_eval(actuelle)) if actuelle.strip() else []
nous = [base + '/claude-screen-normal/', base + '/claude-screen-consigne/']
anciens = [base + '/claude-ecran-normal/', base + '/claude-ecran-consigne/']  # avant le renommage en ClaudeScreen
liste = [p for p in liste if p not in nous + anciens]
if op == '+':
    liste += nous
print(str(liste))
EOF
}

gnome_disponible() {
    command -v gsettings >/dev/null 2>&1 && gsettings list-schemas 2>/dev/null | grep -qx "$SCHEMA"
}

# ------------------------------------------------------------------ ancien nom (ClaudeEcran)
# Le projet s'appelait ClaudeEcran : on retire l'ancienne appli, le démarrage auto et les entrées de menu.
if [ "$OS" = Darwin ]; then
    rm -rf "$HOME/Applications/ClaudeEcran.app"
    rm -f "$HOME/Library/LaunchAgents/local.claudeecran.plist"
else
    rm -f "$HOME/.local/share/applications/claude-ecran.desktop" "$HOME/.config/autostart/claude-ecran.desktop"
fi

# ------------------------------------------------------------------ désinstallation
if [ "$DESINSTALLER" = 1 ]; then
    if [ "$OS" = Darwin ]; then
        rm -rf "$APP"
        [ -f "$AGENT" ] && rm -f "$AGENT"
    else
        rm -f "$BUREAU" "$AUTO"
        if gnome_disponible; then
            gsettings set "$SCHEMA" custom-keybindings "$(liste_gnome -)"
        fi
    fi
    [ -x "$PY" ] && "$PY" "$DIR/claude_screen.py" quitter >/dev/null 2>&1 || true
    info "ClaudeScreen désinstallé. Ce dossier ($DIR) n'a pas été touché ; tu peux le mettre à la corbeille."
    exit 0
fi

# ------------------------------------------------------------------ Python
if [ "$OS" != Darwin ] && [ "$OS" != Linux ]; then
    echo "Système non pris en charge : $OS (pour Windows, utilise la version PowerShell à la racine du dépôt)." >&2
    exit 1
fi

PYSYS="${PYTHON:-python3}"
if ! command -v "$PYSYS" >/dev/null 2>&1; then
    if [ "$OS" = Darwin ]; then
        echo "python3 introuvable. Installe Python 3 depuis https://www.python.org/downloads/macos/ puis relance." >&2
    else
        echo "python3 introuvable. Installe-le (ex. sudo apt install python3 python3-venv) puis relance." >&2
    fi
    exit 1
fi
if ! "$PYSYS" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'; then
    echo "Python 3.9 ou plus récent est nécessaire ($("$PYSYS" --version))." >&2
    exit 1
fi
info "Python : $("$PYSYS" --version) ($(command -v "$PYSYS"))"

MANQUE=()
if ! "$PYSYS" -c 'import tkinter' 2>/dev/null; then
    if [ "$OS" = Darwin ]; then
        avert "Tk absent : les fenêtres utiliseront les boîtes de dialogue macOS. Pour de vraies fenêtres :"
        avert "  brew install python-tk   (Python de Homebrew)   ou   Python de python.org (Tk inclus)"
    else
        MANQUE+=("tk")
    fi
fi

if [ "$OS" = Linux ]; then
    if ! "$PYSYS" -c 'import venv, ensurepip' 2>/dev/null; then MANQUE+=("venv"); fi
    if ! "$PYSYS" - <<'EOF' 2>/dev/null
import gi
for nom in ('AyatanaAppIndicator3', 'AppIndicator3'):
    try:
        gi.require_version(nom, '0.1'); break
    except ValueError:
        pass
else:
    raise SystemExit(1)
EOF
    then MANQUE+=("appindicator"); fi
    if [ ${#MANQUE[@]} -gt 0 ]; then
        avert "Paquets système conseillés manquants : ${MANQUE[*]}"
        if command -v apt-get >/dev/null; then
            avert "  sudo apt install python3-venv python3-tk python3-gi gir1.2-ayatanaappindicator3-0.1"
        elif command -v dnf >/dev/null; then
            avert "  sudo dnf install python3-tkinter python3-gobject libayatana-appindicator-gtk3"
        elif command -v pacman >/dev/null; then
            avert "  sudo pacman -S tk python-gobject libayatana-appindicator"
        elif command -v zypper >/dev/null; then
            avert "  sudo zypper install python3-tk python3-gobject typelib-1_0-AyatanaAppIndicator3-0_1"
        fi
        avert "Sous GNOME, l'icône a aussi besoin de l'extension « AppIndicator » (déjà active sur Ubuntu)."
        if printf '%s\n' "${MANQUE[@]}" | grep -qx venv; then
            echo "Le module venv est indispensable : installe-le puis relance ./installer.sh" >&2
            exit 1
        fi
    fi
fi

# ------------------------------------------------------------------ ancienne organisation
# Les premières versions mettaient les fichiers générés à côté du programme : on les range dans donnees/.
if [ -x "$DIR/.venv/bin/python3" ]; then
    "$DIR/.venv/bin/python3" "$DIR/claude_screen.py" quitter >/dev/null 2>&1 && sleep 2 || true
fi
mkdir -p "$DONNEES"
for f in runs journal.txt reglages.json modele.txt dernier-resultat.txt; do
    if [ -e "$DIR/$f" ]; then
        if [ -e "$DONNEES/$f" ] && [ -d "$DIR/$f" ]; then
            mv "$DIR/$f"/* "$DONNEES/$f"/ 2>/dev/null || true
            rmdir "$DIR/$f" 2>/dev/null || true
        elif [ ! -e "$DONNEES/$f" ]; then
            mv "$DIR/$f" "$DONNEES/$f"
        fi
    fi
done
[ -e "$DIR/outils/icone.png" ] && mv "$DIR/outils/icone.png" "$DONNEES/icone.png"
# Fichiers régénérés automatiquement (lanceur, caches, ancien environnement Python).
rm -rf "$DIR/outils/pc" "$DIR/__pycache__" "$DIR/outils/__pycache__" "$DIR/.venv"

# ------------------------------------------------------------------ environnement virtuel
if [ ! -x "$PY" ]; then
    info "Création de l'environnement Python (donnees/.venv)..."
    if [ "$OS" = Linux ]; then
        # --system-site-packages : accès à PyGObject (gi), installé par le système, pour l'icône AppIndicator.
        "$PYSYS" -m venv --system-site-packages "$VENV"
    else
        "$PYSYS" -m venv "$VENV"
    fi
fi
info "Installation des dépendances..."
"$PY" -m pip install --quiet --upgrade pip
"$PY" -m pip install --quiet -r "$DIR/requirements.txt"
"$PY" -m pip install --quiet --no-deps "pynput>=1.7.6"
chmod +x "$DIR/lancer.sh"

# ------------------------------------------------------------------ lanceurs
if [ "$OS" = Darwin ]; then
    info "Création de $APP..."
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>ClaudeScreen</string>
    <key>CFBundleDisplayName</key><string>ClaudeScreen</string>
    <key>CFBundleIdentifier</key><string>local.claudescreen</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>ClaudeScreen</string>
    <key>CFBundleIconFile</key><string>ClaudeScreen</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>10.15</string>
</dict>
</plist>
EOF
    cat > "$APP/Contents/MacOS/ClaudeScreen" <<EOF
#!/bin/sh
exec "$PY" "$DIR/claude_screen.py"
EOF
    chmod +x "$APP/Contents/MacOS/ClaudeScreen"
    "$PY" "$DIR/claude_screen.py" --icone "$APP/Contents/Resources/ClaudeScreen.icns" || avert "Icône de l'appli non créée."
    codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true

    [ -z "$DEMARRAGE" ] && DEMARRAGE="$(demander "Ouvrir ClaudeScreen automatiquement à la connexion ?" 1)"
    if [ "$DEMARRAGE" = 1 ]; then
        mkdir -p "$(dirname "$AGENT")"
        cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>local.claudescreen</string>
    <key>ProgramArguments</key>
    <array><string>/usr/bin/open</string><string>-g</string><string>-a</string><string>$APP</string></array>
    <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
        info "Démarrage automatique activé (prochaine connexion)."
    elif [ -f "$AGENT" ]; then
        rm -f "$AGENT"
    fi
else
    mkdir -p "$(dirname "$BUREAU")"
    "$PY" "$DIR/claude_screen.py" --icone "$DONNEES/icone.png" || true
    cat > "$BUREAU" <<EOF
[Desktop Entry]
Type=Application
Name=ClaudeScreen
Comment=Claude fait la tâche visible à l'écran (Ctrl+Alt+C)
Exec="$DIR/lancer.sh"
Icon=$DONNEES/icone.png
Terminal=false
Categories=Utility;
EOF
    [ -z "$DEMARRAGE" ] && DEMARRAGE="$(demander "Lancer ClaudeScreen automatiquement à l'ouverture de session ?" 1)"
    if [ "$DEMARRAGE" = 1 ]; then
        mkdir -p "$(dirname "$AUTO")"
        cp "$BUREAU" "$AUTO"
        echo "X-GNOME-Autostart-enabled=true" >> "$AUTO"
        info "Démarrage automatique activé."
    else
        rm -f "$AUTO"
    fi

    if gnome_disponible; then
        if [ -z "$GNOME" ]; then
            defaut=0
            [ "${XDG_SESSION_TYPE:-}" = wayland ] && defaut=1
            GNOME="$(demander "Déclarer Ctrl+Alt+C et Ctrl+Alt+Shift+C dans les raccourcis GNOME (indispensable sous Wayland) ?" "$defaut")"
        fi
        if [ "$GNOME" = 1 ]; then
            gsettings set "$SCHEMA" custom-keybindings "$(liste_gnome +)"
            for nom in normal consigne; do
                cle="$SCHEMA.custom-keybinding:$KPATH/claude-screen-$nom/"
                if [ $nom = normal ]; then
                    gsettings set "$cle" name "ClaudeScreen"
                    gsettings set "$cle" binding "<Control><Alt>c"
                    gsettings set "$cle" command "\"$DIR/lancer.sh\" declencher"
                else
                    gsettings set "$cle" name "ClaudeScreen (avec consigne)"
                    gsettings set "$cle" binding "<Control><Alt><Shift>c"
                    gsettings set "$cle" command "\"$DIR/lancer.sh\" consigne"
                fi
            done
            info "Raccourcis GNOME ajoutés (Paramètres > Clavier > Raccourcis personnalisés)."
        fi
    elif [ "${XDG_SESSION_TYPE:-}" = wayland ]; then
        avert "Session Wayland sans GNOME : ajoute toi-même deux raccourcis dans les réglages du bureau :"
        avert "  Ctrl+Alt+C        ->  \"$DIR/lancer.sh\" declencher"
        avert "  Ctrl+Alt+Shift+C  ->  \"$DIR/lancer.sh\" consigne"
    fi
fi

# ------------------------------------------------------------------ vérifications
case "$DIR" in *" "*) avert "Le chemin de ce dossier contient des espaces : déplace-le (ex. ~/ClaudeScreen), sinon Claude ne pourra pas lancer l'outil de contrôle." ;; esac

echo
info "Diagnostic :"
"$PY" "$DIR/claude_screen.py" diagnostic || true
echo
if ! "$PY" -c 'import sys; sys.path.insert(0, "'"$DIR"'"); import claude_screen; sys.exit(0 if claude_screen.trouver_claude() else 1)' 2>/dev/null; then
    avert "Claude Code n'est pas installé :  curl -fsSL https://claude.ai/install.sh | bash"
    avert "puis lance « claude » une fois pour te connecter avec ton compte, et tape /exit."
fi
if [ "$OS" = Darwin ]; then
    info "Terminé. Ouvre ClaudeScreen depuis ~/Applications (ou : open \"$APP\")."
    echo "Au premier lancement, macOS demande deux autorisations : « Enregistrement de l'écran » et"
    echo "« Accessibilité ». Accepte-les, puis quitte et relance ClaudeScreen (voir README)."
else
    info "Terminé. Lance ClaudeScreen depuis le menu des applications, ou : \"$DIR/lancer.sh\""
fi
