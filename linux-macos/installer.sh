#!/usr/bin/env bash
# Installs ClaudeEcran for macOS or Linux:
#   - Python environment (donnees/.venv) and dependencies;
#     everything generated goes to donnees/, apart from the program;
#   - macOS: the ~/Applications/ClaudeEcran.app app (+ open at login, optional);
#   - Linux: an entry in the applications menu (+ autostart and
#     GNOME keyboard shortcuts, optional).
#
# Options: --demarrage-auto | --sans-demarrage-auto            (autostart on / off)
#          --raccourcis-gnome | --sans-raccourcis-gnome       (GNOME shortcuts on / off, Linux)
#          -y                (accepts the default choices without asking)
#          --desinstaller    (uninstall: removes the app, autostart and shortcuts; keeps this folder)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"
DONNEES="$DIR/donnees"
VENV="$DONNEES/.venv"
PY="$VENV/bin/python3"
APP="$HOME/Applications/ClaudeEcran.app"
AGENT="$HOME/Library/LaunchAgents/local.claudeecran.plist"
BUREAU="$HOME/.local/share/applications/claude-ecran.desktop"
AUTO="$HOME/.config/autostart/claude-ecran.desktop"
SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
KPATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
export PYTHONPYCACHEPREFIX="$DONNEES/cache"  # no __pycache__ next to the program

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
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

info() { printf '\033[1m%s\033[0m\n' "$*"; }
avert() { printf '\033[33m! %s\033[0m\n' "$*"; }

# demander "question" default(1/0) -> 1 or 0
demander() {
    local question="$1" defaut="$2" rep
    if [ "$OUI" = 1 ] || [ ! -t 0 ]; then echo "$defaut"; return; fi
    local choix="[Y/n]"; [ "$defaut" = 0 ] && choix="[y/N]"
    read -r -p "$question $choix " rep </dev/tty || rep=""
    case "$rep" in
        [oOyY]*) echo 1 ;;
        [nN]*) echo 0 ;;
        *) echo "$defaut" ;;
    esac
}

# Adds (+) or removes (-) our two paths from the GNOME list of custom shortcuts.
liste_gnome() {
    python3 - "$1" "$(gsettings get "$SCHEMA" custom-keybindings)" "$KPATH" <<'EOF'
import ast, sys
op, actuelle, base = sys.argv[1], sys.argv[2], sys.argv[3]
actuelle = actuelle.replace('@as ', '')
liste = list(ast.literal_eval(actuelle)) if actuelle.strip() else []
nous = [base + '/claude-ecran-normal/', base + '/claude-ecran-consigne/']
liste = [p for p in liste if p not in nous]
if op == '+':
    liste += nous
print(str(liste))
EOF
}

gnome_disponible() {
    command -v gsettings >/dev/null 2>&1 && gsettings list-schemas 2>/dev/null | grep -qx "$SCHEMA"
}

# ------------------------------------------------------------------ uninstall
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
    [ -x "$PY" ] && "$PY" "$DIR/claude_ecran.py" quitter >/dev/null 2>&1 || true
    info "ClaudeEcran uninstalled. This folder ($DIR) was not touched; you can send it to the trash."
    exit 0
fi

# ------------------------------------------------------------------ Python
if [ "$OS" != Darwin ] && [ "$OS" != Linux ]; then
    echo "Unsupported system: $OS (for Windows, use the PowerShell version at the root of the repository)." >&2
    exit 1
fi

PYSYS="${PYTHON:-python3}"
if ! command -v "$PYSYS" >/dev/null 2>&1; then
    if [ "$OS" = Darwin ]; then
        echo "python3 not found. Install Python 3 from https://www.python.org/downloads/macos/ and run this again." >&2
    else
        echo "python3 not found. Install it (e.g. sudo apt install python3 python3-venv) and run this again." >&2
    fi
    exit 1
fi
if ! "$PYSYS" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'; then
    echo "Python 3.9 or later is required ($("$PYSYS" --version))." >&2
    exit 1
fi
info "Python : $("$PYSYS" --version) ($(command -v "$PYSYS"))"

MANQUE=()
if ! "$PYSYS" -c 'import tkinter' 2>/dev/null; then
    if [ "$OS" = Darwin ]; then
        avert "Tk missing: windows will use macOS dialog boxes. For real windows:"
        avert "  brew install python-tk   (Homebrew Python)   or   Python from python.org (Tk included)"
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
        avert "Missing recommended system packages: ${MANQUE[*]}"
        if command -v apt-get >/dev/null; then
            avert "  sudo apt install python3-venv python3-tk python3-gi gir1.2-ayatanaappindicator3-0.1"
        elif command -v dnf >/dev/null; then
            avert "  sudo dnf install python3-tkinter python3-gobject libayatana-appindicator-gtk3"
        elif command -v pacman >/dev/null; then
            avert "  sudo pacman -S tk python-gobject libayatana-appindicator"
        elif command -v zypper >/dev/null; then
            avert "  sudo zypper install python3-tk python3-gobject typelib-1_0-AyatanaAppIndicator3-0_1"
        fi
        avert "On GNOME, the icon also needs the \"AppIndicator\" extension (already enabled on Ubuntu)."
        if printf '%s\n' "${MANQUE[@]}" | grep -qx venv; then
            echo "The venv module is required: install it and run ./installer.sh again" >&2
            exit 1
        fi
    fi
fi

# ------------------------------------------------------------------ old layout
# Early versions put generated files next to the program: move them into donnees/.
if [ -x "$DIR/.venv/bin/python3" ]; then
    "$DIR/.venv/bin/python3" "$DIR/claude_ecran.py" quitter >/dev/null 2>&1 && sleep 2 || true
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
# Automatically regenerated files (launcher, caches, old Python environment).
rm -rf "$DIR/outils/pc" "$DIR/__pycache__" "$DIR/outils/__pycache__" "$DIR/.venv"

# ------------------------------------------------------------------ virtual environment
if [ ! -x "$PY" ]; then
    info "Creating the Python environment (donnees/.venv)..."
    if [ "$OS" = Linux ]; then
        # --system-site-packages: access to PyGObject (gi), installed by the system, for the AppIndicator icon.
        "$PYSYS" -m venv --system-site-packages "$VENV"
    else
        "$PYSYS" -m venv "$VENV"
    fi
fi
info "Installing dependencies..."
"$PY" -m pip install --quiet --upgrade pip
"$PY" -m pip install --quiet -r "$DIR/requirements.txt"
"$PY" -m pip install --quiet --no-deps "pynput>=1.7.6"
chmod +x "$DIR/lancer.sh"

# ------------------------------------------------------------------ launchers
if [ "$OS" = Darwin ]; then
    info "Creating $APP..."
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>ClaudeEcran</string>
    <key>CFBundleDisplayName</key><string>ClaudeEcran</string>
    <key>CFBundleIdentifier</key><string>local.claudeecran</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>ClaudeEcran</string>
    <key>CFBundleIconFile</key><string>ClaudeEcran</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>10.15</string>
</dict>
</plist>
EOF
    cat > "$APP/Contents/MacOS/ClaudeEcran" <<EOF
#!/bin/sh
exec "$PY" "$DIR/claude_ecran.py"
EOF
    chmod +x "$APP/Contents/MacOS/ClaudeEcran"
    "$PY" "$DIR/claude_ecran.py" --icone "$APP/Contents/Resources/ClaudeEcran.icns" || avert "App icon not created."
    codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true

    [ -z "$DEMARRAGE" ] && DEMARRAGE="$(demander "Open ClaudeEcran automatically at login?" 1)"
    if [ "$DEMARRAGE" = 1 ]; then
        mkdir -p "$(dirname "$AGENT")"
        cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>local.claudeecran</string>
    <key>ProgramArguments</key>
    <array><string>/usr/bin/open</string><string>-g</string><string>-a</string><string>$APP</string></array>
    <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
        info "Autostart enabled (next login)."
    elif [ -f "$AGENT" ]; then
        rm -f "$AGENT"
    fi
else
    mkdir -p "$(dirname "$BUREAU")"
    "$PY" "$DIR/claude_ecran.py" --icone "$DONNEES/icone.png" || true
    cat > "$BUREAU" <<EOF
[Desktop Entry]
Type=Application
Name=ClaudeEcran
Comment=Claude does the task visible on screen (Ctrl+Alt+C)
Exec="$DIR/lancer.sh"
Icon=$DONNEES/icone.png
Terminal=false
Categories=Utility;
EOF
    [ -z "$DEMARRAGE" ] && DEMARRAGE="$(demander "Start ClaudeEcran automatically at login?" 1)"
    if [ "$DEMARRAGE" = 1 ]; then
        mkdir -p "$(dirname "$AUTO")"
        cp "$BUREAU" "$AUTO"
        echo "X-GNOME-Autostart-enabled=true" >> "$AUTO"
        info "Autostart enabled."
    else
        rm -f "$AUTO"
    fi

    if gnome_disponible; then
        if [ -z "$GNOME" ]; then
            defaut=0
            [ "${XDG_SESSION_TYPE:-}" = wayland ] && defaut=1
            GNOME="$(demander "Add Ctrl+Alt+C and Ctrl+Alt+Shift+C to the GNOME shortcuts (required on Wayland)?" "$defaut")"
        fi
        if [ "$GNOME" = 1 ]; then
            gsettings set "$SCHEMA" custom-keybindings "$(liste_gnome +)"
            for nom in normal consigne; do
                cle="$SCHEMA.custom-keybinding:$KPATH/claude-ecran-$nom/"
                if [ $nom = normal ]; then
                    gsettings set "$cle" name "ClaudeEcran"
                    gsettings set "$cle" binding "<Control><Alt>c"
                    gsettings set "$cle" command "\"$DIR/lancer.sh\" declencher"
                else
                    gsettings set "$cle" name "ClaudeEcran (avec consigne)"
                    gsettings set "$cle" binding "<Control><Alt><Shift>c"
                    gsettings set "$cle" command "\"$DIR/lancer.sh\" consigne"
                fi
            done
            info "GNOME shortcuts added (Settings > Keyboard > Custom Shortcuts)."
        fi
    elif [ "${XDG_SESSION_TYPE:-}" = wayland ]; then
        avert "Wayland session without GNOME: add two shortcuts yourself in the desktop settings:"
        avert "  Ctrl+Alt+C        ->  \"$DIR/lancer.sh\" declencher"
        avert "  Ctrl+Alt+Shift+C  ->  \"$DIR/lancer.sh\" consigne"
    fi
fi

# ------------------------------------------------------------------ checks
case "$DIR" in *" "*) avert "The path of this folder contains spaces: move it (e.g. ~/ClaudeEcran), otherwise Claude cannot run the control tool." ;; esac

echo
info "Diagnostic :"
"$PY" "$DIR/claude_ecran.py" diagnostic || true
echo
if ! "$PY" -c 'import sys; sys.path.insert(0, "'"$DIR"'"); import claude_ecran; sys.exit(0 if claude_ecran.trouver_claude() else 1)' 2>/dev/null; then
    avert "Claude Code is not installed:  curl -fsSL https://claude.ai/install.sh | bash"
    avert "then run \"claude\" once to log in with your account, and type /exit."
fi
if [ "$OS" = Darwin ]; then
    info "Done. Open ClaudeEcran from ~/Applications (or: open \"$APP\")."
    echo "On first launch, macOS asks for two permissions: \"Screen Recording\" and"
    echo "\"Accessibility\". Allow them, then quit and relaunch ClaudeEcran (see README)."
else
    info "Done. Start ClaudeEcran from the applications menu, or: \"$DIR/lancer.sh\""
fi
