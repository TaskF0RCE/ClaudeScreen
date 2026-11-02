# ClaudeScreen for macOS and Linux

Port of [ClaudeScreen](../README.md) (Windows version): a keyboard shortcut gives Claude what is on your screen, so it does the task for you (answer a multiple-choice quiz, fill in a form, type commands in Packet Tracer or GNS3, create a file...).

There is no window, only an icon in the **menu bar** (macOS) or the **notification area** (Linux).

Like the Windows version, it runs on top of the **[Claude Code](https://docs.claude.com/en/docs/claude-code) CLI** (`claude -p`) with your own Claude account.

> Personal project, unofficial, not affiliated with Anthropic.

## How it works

Same as the Windows version:

1. Press **⌃⌥C** (Ctrl+Option+C) on a Mac, or **Ctrl+Alt+C** on Linux.
2. The app takes a screenshot of the screen your mouse is on.
3. **Haiku** looks at the screenshot and picks **Sonnet** (quiz, course question, simple form) or **Opus** (calculations, programming, networking, infrastructure). If the active window is Packet Tracer, GNS3, PuTTY, Wireshark, MATLAB, etc., Opus is picked directly.
4. Claude does the task with the mouse and keyboard, takes a new screenshot after each action to check, then writes a short summary.
5. Click the icon → **Last result** to read it.

**⌃⌥⇧C** / **Ctrl+Alt+Shift+C** takes the screenshot, then opens a small bar in the bottom-left corner: type an instruction ("only do question 4", "configure OSPF on R1 and R2"), then **Enter**. **Esc** or clicking elsewhere cancels.

Pressing the shortcut again during a task stops it (or use the **Stop the current task** menu). Automatic stop after 20 minutes. During a task, don't touch the mouse or keyboard.

### The icon

| Icon | Meaning |
|---|---|
| Still star | Ready |
| Spinning star | Working |
| Green dot | Done: open "Last result" |
| Red dot | Error: open "Last result" for the message |

Menu: **Last result**, **Model** (Auto, Always Sonnet, Always Opus; the choice is remembered), **Open the Claude-Travail folder**, **Stop the current task**, **Quit**.

On macOS and with most Linux desktops (AppIndicator), clicking the icon opens the menu; "Last result" is the first entry.

## Installation

### 1. Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude        # log in once with your Claude account, then type /exit
```

### 2. ClaudeScreen

Copy the `linux-macos` folder wherever you like (in a path **without spaces**, for example `~/ClaudeEcran`), then:

```bash
cd ~/ClaudeEcran/linux-macos      # adjust the path
./installer.sh
```

The script creates a Python environment in `donnees/.venv`, installs the dependencies, creates the launcher, offers to start the app automatically and prints a diagnostic. Options: `--demarrage-auto` (autostart), `--sans-demarrage-auto` (no autostart), `--raccourcis-gnome` (GNOME shortcuts), `-y` (no questions), `--desinstaller` (uninstall).

### macOS (10.15 or later)

- Requirement: Python 3.9+ ([python.org](https://www.python.org/downloads/macos/) recommended: Tk is included, so the instruction bar and the result window are real windows. With Homebrew: `brew install python python-tk`).
- The installer creates **`~/Applications/ClaudeEcran.app`**: open it (Spotlight → "ClaudeEcran").
- **Permissions**: on first launch, macOS asks for
  - **Screen Recording** (for screenshots);
  - **Accessibility** (to click and type).

  Allow both in *System Settings → Privacy & Security*, then **quit and relaunch** ClaudeEcran. Depending on the macOS version, the item to tick is called "ClaudeEcran", "Python" or "Terminal" (if you started it from Terminal). If in doubt: `./lancer.sh diagnostic`.
- The ⌃⌥C shortcut is registered like on Windows (RegisterEventHotKey): no extra permission needed, and other apps no longer receive it while ClaudeEcran is running.
- Autostart: the installer adds `~/Library/LaunchAgents/local.claudeecran.plist`.
- Keyboard shortcuts for Claude: on a Mac it uses `cmd+c`, `cmd+v`, `cmd+s`... (its instructions tell it so), and `ctrl` remains available for terminals.

### Linux

An **X11** session ("Ubuntu on Xorg", "GNOME on Xorg", KDE X11, Xfce, MATE, Cinnamon...) works fully. For **Wayland**, see below.

Useful system packages (the installer tells you which ones are missing):

```bash
# Debian / Ubuntu / Mint
sudo apt install python3-venv python3-tk python3-gi gir1.2-ayatanaappindicator3-0.1
# Fedora
sudo dnf install python3-tkinter python3-gobject libayatana-appindicator-gtk3
# Arch
sudo pacman -S tk python-gobject libayatana-appindicator
```

- On GNOME, the icon needs the **AppIndicator** extension (enabled by default on Ubuntu; elsewhere: "AppIndicator and KStatusNotifierItem Support").
- Launch: applications menu → **ClaudeEcran**, or `./lancer.sh`.
- Autostart: `~/.config/autostart/claude-ecran.desktop`.

#### Wayland

Wayland deliberately prevents apps from listening to the keyboard, reading the screen and driving the mouse of other windows. ClaudeScreen partly works around it:

| Feature | On Wayland |
|---|---|
| Shortcut | Declared in the desktop settings; the installer does it for GNOME (`--raccourcis-gnome`). Elsewhere (KDE...), add two custom shortcuts: Ctrl+Alt+C → `".../lancer.sh" declencher` and Ctrl+Alt+Shift+C → `".../lancer.sh" consigne`. |
| Screenshot | With `grim` (Sway, Hyprland), `gnome-screenshot` (GNOME) or `spectacle` (KDE). Always the first screen. |
| Mouse and keyboard | With [`ydotool`](https://github.com/ReimuNotMoe/ydotool) (version 1.x, `ydotoold` service running, access to `/dev/uinput`). Disable mouse acceleration for accurate clicks. Typing is limited to the QWERTY layout. Without ydotool, only XWayland apps receive the clicks. |
| Active window | Unknown (the Packet Tracer → Opus shortcut doesn't work, Haiku picks). |

**Tip: for reliable use, open an X11 session** (login screen → gear icon → "Ubuntu on Xorg").

## Commands

```bash
./lancer.sh               # starts the app
./lancer.sh declencher    # same as Ctrl+Alt+C
./lancer.sh consigne      # same as Ctrl+Alt+Shift+C
./lancer.sh arreter       # stops the current task
./lancer.sh resultat      # shows the last result
./lancer.sh etat          # ready / working
./lancer.sh quitter       # quits
./lancer.sh diagnostic    # checks screenshot, permissions, Claude Code, modules...
```

## Security

As on Windows, Claude is started with limited permissions (`reglages.json`, generated at startup). It can only:

- read the screenshots;
- click, type and scroll, through `donnees/pc` (no other command is allowed);
- create or edit files in `~/Documents/Claude-Travail`.

On top of that:

- **Nothing is ever permanently deleted.** The hook `outils/garde.py` blocks `rm`, `rmdir`, `unlink`, `shred`, `find -delete`, `dd`, `mkfs`, `diskutil erase`, `git clean`, `shutdown`, etc. To remove a file, Claude sends it to the trash (`pc corbeille`).
- Its instructions forbid buying, paying, sending messages, entering passwords or bank details, and changing system settings. Text displayed on screen cannot override these rules.
- No web access (WebFetch and WebSearch are denied).

## Subscription and usage

Same as the Windows version: each task uses your Claude quota (one very short Haiku call, then Sonnet or Opus; screenshots weigh a lot). If the limit is reached, the task fails with a red dot. Without a subscription, Claude Code can use an API key (`ANTHROPIC_API_KEY`, passed on to Claude).

## Structure

```
claude_ecran.py     app (menu bar / notification area): shortcuts, screenshot, model triage, starting Claude
installer.sh        installation: Python environment, dependencies, ClaudeEcran.app (macOS) or menu entry (Linux), autostart
lancer.sh           starts the app in the background, or sends it a command (declencher, consigne...)
requirements.txt    Python dependencies
outils/natif.py     system calls: screens, screenshot, mouse, keyboard (XTest on X11), active window, trash
outils/raccourcis.py global shortcuts (Carbon on macOS, X11 listener on Linux)
outils/fenetres.py  "last result" window and instruction bar (Tk, separate process)
outils/pc.py        computer control tool used by Claude
outils/garde.py     hook that blocks permanent deletions
donnees/            EVERYTHING generated, kept apart from the program (private, ignored by git):
  runs/               task screenshots and answers, deleted after 30 days
  journal.txt         app log
  reglages.json       permissions given to Claude (regenerated at each start)
  pc                  launcher of outils/pc.py used by Claude (regenerated at each start)
  modele.txt          model choice (Model menu)
  dernier-resultat.txt
  icone.png           applications menu icon (Linux)
  .venv/              Python environment created by installer.sh
  cache/              compiled Python files
```

Mapping to the Windows version: `ClaudeEcran.ps1` → `claude_ecran.py`, `Lancer.vbs` → `lancer.sh` / `ClaudeEcran.app`, `natif.cs` + `natif.ps1` → `natif.py` + `raccourcis.py`, `pc.ps1` → `pc.py`, `garde.ps1` → `garde.py`.

## Limitations

- Same limitations as the Windows version: Claude runs no program other than the control tool; precise drag and drop is slow; only one screen is captured (the one with the mouse).
- Wayland: see the table above.
- macOS: if you move the folder after installing, run `./installer.sh` again (the app and the autostart contain the path). On macOS 15 and later, the system may periodically ask again for the screen recording permission.
