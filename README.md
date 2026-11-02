# ClaudeScreen

A Windows keyboard shortcut that gives Claude what is on your screen, so it does the task for you: answer a multiple-choice quiz, fill in a form, type commands in Packet Tracer or GNS3, create a file (code, diagram, summary...).

There is no window, only an icon in the notification area of the taskbar.

ClaudeScreen runs on top of the **[Claude Code](https://docs.claude.com/en/docs/claude-code) CLI**: it calls `claude` in non-interactive mode (`claude -p`) with your own Claude account, so there is no API to set up and no server to run. Install Claude Code, log in once, and the shortcut works.

> Personal project, unofficial, not affiliated with Anthropic.

> **macOS and Linux:** a port lives in [`linux-macos/`](linux-macos/README.md).

## How it works

1. Press **Ctrl+Alt+C** (or **Ctrl+Alt+Copilot key**).
2. The app takes a screenshot of the screen your mouse is on.
3. **Haiku** looks at the screenshot and picks the model:
   - **Sonnet** for a multiple-choice quiz, a course question or a simple form (fast, uses little quota);
   - **Opus** for calculations, programming, networking and infrastructure (subnetting, VLANs, routers...).
   If the active window is Packet Tracer, GNS3, PuTTY, Wireshark, MATLAB, etc., Opus is picked directly, without triage.
4. Claude does the task with the mouse and keyboard, takes a new screenshot after each action to check, then writes a short summary (in French by default).
5. Click the icon to see the summary.

### Giving an instruction

**Ctrl+Alt+Shift+C** takes the screenshot, then opens a tiny bar in the bottom-left corner of the screen. Type your instruction, for example "only do question 4" or "configure OSPF on R1 and R2", then press **Enter**. The instruction takes priority over everything else.

- **Esc** or clicking elsewhere cancels the task and deletes the screenshot.
- **Enter** on an empty bar starts a normal task.

### Standing context (optional)

The `Documents\Claude-Travail\System-Context` folder is created on first launch.

- **`instructions.txt`**: your standing instructions, one per line, added to every task. For example: "I'm a BTS SIO student", "always answer in French". Lines starting with `#` are ignored: as long as you write nothing else, the file does nothing.
- **The other files in the folder** (courses, PDFs, assignments...): Claude gets their list with every task and reads the useful ones. It is not allowed to modify them.

Priority order: the instruction typed in the bar, then `instructions.txt`, then what Claude infers from the screen.

### Packet Tracer

You place the devices and connect them. Claude touches neither devices nor cables: it configures each device through its **CLI** tab (one command file per device, typed into the console) and checks with `show` commands. For PCs, it uses Desktop > IP Configuration.

### The icon

| Icon | Meaning |
|---|---|
| Still star | Ready |
| Spinning star | Working |
| Green dot | Done: click to see the result |
| Red dot | Error: click to see the message |

Right-click the icon:
- **Last result**
- **Model**: Auto, Always Sonnet or Always Opus (the choice is remembered)
- **Open the Claude-Travail folder**
- **Stop the current task**
- **Quit**

### Stopping a task

Press **Ctrl+Alt+C** again while the star is spinning, or use **Stop the current task** in the menu. A task is also stopped automatically after 20 minutes.

During a task, don't touch the mouse or keyboard: Claude uses the real ones. If another window comes to the front, it stops by itself so it doesn't type in the wrong place.

## Security

Claude is started with limited permissions (`reglages.json`, generated at startup). It can only:

- read the screenshots;
- click, type and scroll, through `outils/pc.ps1` (no other command is allowed);
- create or edit files in `Documents\Claude-Travail`.

On top of that:

- **Nothing is ever permanently deleted.** The hook `outils/garde.ps1` blocks `Remove-Item`, `del`, `rm`, `format`, etc. To remove a file, Claude sends it to the Recycle Bin (`pc.ps1 corbeille`).
- Its instructions forbid buying, paying, sending messages, entering passwords or bank details, and changing Windows settings. Text displayed on screen cannot override these rules.
- No web access (WebFetch and WebSearch are denied).

## Installation

Requirements: Windows 10 or 11, with PowerShell 5.1 (built into Windows). Nothing else to install besides Claude Code.

1. Install the Claude Code CLI:
   ```powershell
   irm https://claude.ai/install.ps1 | iex
   ```
2. Log in once: run `%USERPROFILE%\.local\bin\claude.exe`, choose to log in with your Claude account, then type `/exit`.
3. Copy this folder to `%USERPROFILE%\ClaudeEcran` (or anywhere else: paths are relative to the script's folder).
4. Make it start with Windows and launch it right away:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\ClaudeEcran\Installer-Demarrage.ps1"
   Start-ScheduledTask -TaskName ClaudeEcran
   ```
   The icon appears in the notification area. A scheduled task named "ClaudeEcran" restarts it 20 s after each logon, without any window. To remove it, add `-Retirer` to the first command.

`Lancer.vbs` can also start it by hand (double-click), but Windows is phasing out VBScript: prefer the scheduled task.

> **Don't put the folder in `AppData`** if you install it from Claude Desktop (Microsoft Store app). Windows then redirects the files to a private Claude Desktop folder that is invisible at startup, and you get "file not found".

## Shortcuts

| Shortcut | Status |
|---|---|
| Ctrl+Alt+C | Active |
| Ctrl+Alt+Copilot key | Active |
| Ctrl+Alt+Shift+C | Active, with the instruction bar |
| Copilot key alone (Win+Shift+F23) | Reserved by Windows, usually unavailable |

Ctrl+Alt+C is global: while the app is running, other programs no longer receive it. A few use it, for example Visual Studio (the "Call Stack" window while debugging) or Photoshop ("Canvas Size"). If that bothers you, use Ctrl+Alt+Copilot or change the shortcut in `ClaudeEcran.ps1` (`$raccourcis.Enregistrer(...)`).

## Subscription and usage

- Each task uses your Claude quota: one very short Haiku call, then Sonnet or Opus. Screenshots weigh a lot; a 50-question quiz needs several dozen of them.
- If your subscription expires or the limit is reached, the task fails with a red dot and the error message. Nothing else happens.
- Without a subscription, Claude Code can also run with a pay-as-you-go API key (`ANTHROPIC_API_KEY` environment variable).

## Structure

```
ClaudeEcran.ps1     notification-area app: shortcuts, screenshot, model triage, starting Claude
Lancer.vbs          starts the app without a window (by hand)
Installer-Demarrage.ps1  installs or removes the startup scheduled task
outils/natif.cs     Windows calls (DPI, screenshot, mouse, keyboard, global hotkeys, active window)
outils/natif.ps1    compiles natif.cs into a DLL only once (the name changes when the source changes)
outils/pc.ps1       PC control tool used by Claude
outils/garde.ps1    hook that blocks permanent deletions
runs/               task screenshots and answers, deleted after 30 days (private, ignored by git)
journal.txt         app log (private, ignored by git)
```

Files created by Claude go to `Documents\Claude-Travail`.

Automatic cleanup: at startup and then every 6 hours, the app permanently deletes the `runs/` folders older than 30 days (`$JoursConserves` variable in `ClaudeEcran.ps1`). They don't go through the Recycle Bin, so the space is really freed. The log is trimmed too. Files in `Documents\Claude-Travail` are never touched.

## Limitations

- Claude cannot run any program or command other than the control tool. For example, it cannot generate an image with Python, but it can write a diagram in SVG or HTML.
- Precise drag and drop (cables in Packet Tracer, for example) is slow and not always reliable: that's why you do the cabling and Claude configures through the console.
- For websites, the Claude in Chrome extension is often more reliable: it reads the page content directly instead of going through screenshots.
- Only one screen is captured: the one the mouse is on when you press the shortcut.

## Contributing and versions

The workflow (issue → branch → PR → review → merge) is described in [CONTRIBUTING.md](CONTRIBUTING.md); the easiest way is through the [VeD Opps dashboard](https://taskf0rce.github.io/VeD_Opps/).
Versions are published automatically (the dashboard's « Nouvelle release » button): see the [releases](../../releases) and `CHANGELOG.md`.
