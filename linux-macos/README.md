# ClaudeScreen for macOS and Linux

Port of [ClaudeScreen](../README.md) (Windows version): a keyboard shortcut gives Claude what is on your screen, so it does the task for you (fill in a form, answer questions, carry on with a document, configure something in an application, create a file...).

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

### Standing context (optional)

Like on Windows, the **`~/Documents/Claude-Work/System-Context`** folder is created on first launch, with a `README.md` that explains how to use it (use the **Open the Claude-Work folder** menu to get there). The work folder was called `Claude-Travail` in older versions: it is renamed automatically, with everything in it.

- **`instructions.md`**: your standing instructions, one per line, added to every task while the app is running ("I'm a second-year computer science student", "never click Finish exam", "always answer in English"...). Comments (`<!-- ... -->`) are ignored. The file is re-read for every task: a change applies right away. **This file is yours: neither the app nor Claude ever changes it.** A file from an older version is converted once: an `instructions.txt` becomes `instructions.md` (its `#` lines become comments, the old file goes to the trash), and the notes Claude used to keep at the end of `instructions.md` move to `memory.md`.
- **`memory.md`**: Claude's notes, when [Persistent memory](#persistent-memory) is on.
- **The other files**, subfolders included (courses, notes, technical documentation, assignments, bibliography, sources...): Claude gets their list with every task, treats them as more reliable than its general knowledge, reads the ones related to the task and relies on them first. Best-read formats: `.pdf`, `.txt`, `.md`, images, code, `.csv`, `.html` (for a Word or Keynote file, also export it as PDF). Hidden or temporary files (`.DS_Store`, `~$...`) are ignored, as is the folder's `README.md`.
- **PDFs**: the app extracts their text in advance, page by page, into `data/context-cache/` (at startup, then only when a PDF changes), with the `pypdfium2` Python library: nothing extra to install, no need for `pdftoppm`. Claude reads that text, which is fast and saves quota, and can search it. For a diagram or a scanned PDF (no text), it shows the page as an image with the `page-pdf` action. If you installed ClaudeScreen before this feature, run `./installer.sh` again to add `pypdfium2`.
- **Read-only**: Claude can read this folder, but cannot change, move, send to the trash or run anything in it.
- **Contexts**: who you are and how to work for you, one small file per context in `System-Context/Contexts` (Default, Studies, Software development, Networking, Office productivity...). Pick the active one in the icon menu (**Context**); edit the files, add your own or remove some, as explained in the [Windows README](../README.md#contexts).
- **Know-how for one piece of software**: the `examples` folder at the root of the repository has ready-made files (`packet-tracer.md`...). Copy the ones you use into `System-Context`.

Priority order: the instruction from the bar (for one task), then `instructions.md` (for every task), then what Claude infers from the screen.

The folder is in your Documents, outside the repository: its contents never end up on GitHub.

### The icon

| Icon | Meaning |
|---|---|
| Still star | Ready |
| Spinning star | Working |
| Green dot | Done: open "Last result" |
| Red dot | Error: open "Last result" for the message |

Menu: **Last result**, **Model** (Auto, Always Sonnet, Always Opus; the choice is remembered), **Smooth mode**, **Persistent memory** (see below), **Open the Claude-Work folder**, **Stop the current task**, **Quit**. The icon's tooltip and the result window are named **Claude-Work** too.

On macOS and with most Linux desktops (AppIndicator), clicking the icon opens the menu; "Last result" is the first entry.

### Smooth mode

Same as on Windows: with **Smooth mode** checked in the menu, the mouse glides to its target like a hand (slightly curved path, speeds up then slows down, about 0.2 s for a short hop and 0.75 s across the screen, short pause before clicking) and the text is typed one key at a time at a human pace (about 9 characters per second, longer pauses after a space, punctuation and Enter). A long text is typed faster so that one action never takes more than about 45 seconds. The choice is remembered (`data/smooth.txt`) and applies at once, even during a task. The settings are in `outils/humain.py`.

### Persistent memory

Same as on Windows ([details](../README.md#persistent-memory)): with **Persistent memory** checked in the menu (it is by default), Claude ends each task with short notes (what it learned about you and your work, how far it got) and gets them back at the next tasks, a kind of mini session. The notes go into `System-Context/memory.md`, one per line; `instructions.md` is never touched. **Unchecking the mode empties `memory.md`** (the notes it just cleared are kept once in `data/memory-previous.md`). Claude cannot write in the folder: it ends its answer with `MEMORY: ...` lines, and the app saves them and hides them from the result (300 characters per note, 4000 in all; past that, the oldest notes make room). The choice is remembered (`data/memory.txt`). The code is in `outils/memoire.py`.

On Wayland, the mouse position cannot be read: the first move of a task jumps to its target, the next ones glide from the last known position.

## Installation

### 1. Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude        # log in once with your Claude account, then type /exit
```

### 2. ClaudeScreen

Copy the `linux-macos` folder wherever you like (in a path **without spaces**, for example `~/ClaudeScreen`), then:

```bash
cd ~/ClaudeScreen/linux-macos      # adjust the path
./installer.sh
```

The script creates a Python environment in `data/.venv`, installs the dependencies, creates the launcher, offers to start the app automatically and prints a diagnostic. Options: `--demarrage-auto` (autostart), `--sans-demarrage-auto` (no autostart), `--raccourcis-gnome` (GNOME shortcuts), `-y` (no questions), `--desinstaller` (uninstall).

### macOS (10.15 or later)

- Requirement: Python 3.9+ ([python.org](https://www.python.org/downloads/macos/) recommended: Tk is included, so the instruction bar and the result window are real windows. With Homebrew: `brew install python python-tk`).
- The installer creates **`~/Applications/ClaudeScreen.app`**: open it (Spotlight → "ClaudeScreen").
- **Permissions**: on first launch, macOS asks for <br>
  1\. System Settings → Privacy & Security → Accessibility <br>
  2\. System Settings → Privacy & Security → Screen & System Audio Recording

  Allow both in *System Settings → Privacy & Security*, then **quit and relaunch** ClaudeScreen. Depending on the macOS version, the item to tick is called "ClaudeScreen", "Python" or "Terminal" (if you started it from Terminal). If in doubt: `./lancer.sh diagnostic`.
- The ⌃⌥C shortcut is registered like on Windows (RegisterEventHotKey): no extra permission needed, and other apps no longer receive it while ClaudeScreen is running.
- Autostart: the installer adds `~/Library/LaunchAgents/local.claudescreen.plist`.
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
- Launch: applications menu → **ClaudeScreen**, or `./lancer.sh`.
- Autostart: `~/.config/autostart/claude-screen.desktop`.

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

As on Windows, Claude is started with limited permissions (`data/settings.json`, generated at startup). It can only:

- read the screenshots;
- click, type and scroll, through the `pc` tool of `outils/mcp.py` (there is no terminal: no command can be run);
- create or edit files in `~/Documents/Claude-Work` (except in `System-Context`, which is read-only).

On top of that:

- **`System-Context` is read-only**, locked three times: a `deny` rule in `data/settings.json` (`Edit(//...)`, which also covers Write), the hook `outils/garde.py` that refuses any file write in that folder (including through a symbolic link or `..`), and the `corbeille` action that refuses to touch it (or `Claude-Work`, which contains it). Claude has no way to write there: its [Persistent memory](#persistent-memory) notes are saved by the app itself.
- **Nothing is deleted permanently.** Claude has no terminal, and to remove a file it sends it to the trash (the `corbeille` action). The hook `outils/garde.py` stays as a second lock: if a command tool were ever given to Claude, it blocks `rm`, `rmdir`, `unlink`, `shred`, `find -delete`, `dd`, `mkfs`, `diskutil erase`, `git clean`, `shutdown`, etc.
- Its instructions forbid buying, paying, sending messages, entering passwords or bank details, changing system settings and deleting anything for good. Text displayed on screen cannot override these rules. This part relies on Claude: what it does with the mouse and keyboard is not filtered by the program.
- No web access (WebFetch and WebSearch are denied).
- Claude is started with only the tools a task needs (`Read`, `Write`, `Edit`, `Glob`, `Grep` and the `pc` tool), without the MCP servers, connectors and skills of your account. This needs a recent Claude Code: the app runs `claude update` in the background at startup and then once a day, never during a task.

## Subscription and usage

Same as the Windows version: each task uses your Claude quota (one very short Haiku call, then Sonnet or Opus; screenshots weigh a lot). If the limit is reached, the task fails with a red dot. Without a subscription, Claude Code can use an API key (`ANTHROPIC_API_KEY`, passed on to Claude).

## Structure

```
claude_screen.py    app (menu bar / notification area): shortcuts, screenshot, model triage, starting Claude
installer.sh        installation: Python environment, dependencies, ClaudeScreen.app (macOS) or menu entry (Linux), autostart
lancer.sh           starts the app in the background, or sends it a command (declencher, consigne...)
requirements.txt    Python dependencies
outils/natif.py     system calls: screens, screenshot, mouse, keyboard (XTest on X11), active window, trash
outils/raccourcis.py global shortcuts (Carbon on macOS, X11 listener on Linux)
outils/fenetres.py  "last result" window and instruction bar (Tk, separate process)
outils/pc.py        the computer control actions (click, type, screenshot, trash...)
outils/mcp.py       MCP server that gives these actions to Claude: several actions per call, screenshot in the answer
outils/humain.py    smooth mode: mouse path and typing pace that look human
outils/garde.py     hook that blocks permanent deletions and writes to System-Context
outils/pdf.py       PDF reading: text extracted in advance, page as an image (pypdfium2)
outils/memoire.py   instructions.md (yours, never changed) and memory.md (Claude's notes, persistent memory)
outils/System-Context-README.md  user guide copied into ~/Documents/Claude-Work/System-Context (kept up to date at each start)
data/               EVERYTHING the app generates, kept apart from the program (private, ignored by git):
  runs/<date>/        one folder per task, deleted after 30 days:
    images/             screenshot-01.png, zoom-01.png, pdf-01.png...
    prompts/            task.txt (instructions sent to Claude), triage.txt (model choice)
    responses/          task.txt, task-errors.txt, triage.txt, triage-errors.txt
    screen.json         position and scale of the captured screen
  context-cache/      text extracted from the System-Context PDFs (rebuilt when needed)
  log.txt             app log
  settings.json       permissions given to Claude (regenerated at each start)
  model.txt           model choice (Model menu)
  smooth.txt          smooth mode: on or off (Smooth mode menu)
  memory.txt          persistent memory: on or off (Persistent memory menu)
  last-result.txt     text shown by "Last result"
  memory-previous.md  the notes cleared the last time Persistent memory was unchecked
  icon.png            applications menu icon (Linux)
  .venv/              Python environment created by installer.sh
  cache/              compiled Python files
```

Same `data/` layout as the Windows version. Coming from an older version (`donnees/` folder): run `./installer.sh` again, it moves your history into `data/` and rebuilds the Python environment.

Mapping to the Windows version: `ClaudeScreen.ps1` → `claude_screen.py`, `Lancer.vbs` → `lancer.sh` / `ClaudeScreen.app`, `natif.cs` + `natif.ps1` → `natif.py` + `raccourcis.py`, `actions.ps1` → `pc.py`, `mcp.ps1` → `mcp.py`, smooth mode of `natif.cs` → `humain.py`, `garde.ps1` → `garde.py`, `pdf.ps1` + `poppler.ps1` → `pdf.py` (pypdfium2, no external program), `memoire.ps1` → `memoire.py`.

## Limitations

- Same limitations as the Windows version: Claude runs no program other than the control tool; precise mouse work (cabling in Packet Tracer, drag and drop) is slow; only one screen is captured (the one with the mouse).
- Wayland: see the table above.
- **Terminal access** is not ported: Claude has the mouse, the keyboard and its files, and runs no command. The MCP server (`outils/mcp.py`) is new here and has been tested with the protocol only, not yet on many real machines: if a result says that the control tool did not start, run `claude update` and try again. The result and the log show how long each task took.
- macOS: if you move the folder after installing, run `./installer.sh` again (the app and the autostart contain the path). On macOS 15 and later, the system may periodically ask again for the screen recording permission.
