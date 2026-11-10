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

In the notification area the app is called **Claude-Work** (tooltip, menu, result window), like the folder in your Documents where Claude puts the files it creates.

### Giving an instruction

**Ctrl+Alt+Shift+C** takes the screenshot, then opens a tiny bar in the bottom-left corner of the screen. Type your instruction, for example "only do question 4" or "configure OSPF on R1 and R2", then press **Enter**. The instruction takes priority over everything else.

- **Esc** or clicking elsewhere cancels the task and deletes the screenshot.
- **Enter** on an empty bar starts a normal task.

### Standing context (optional)

The `Documents\Claude-Work\System-Context` folder is created on first launch, with a `README.md` that explains how to use it. (The work folder was called `Claude-Travail` in older versions: it is renamed automatically, with everything in it.)

- **`instructions.md`**: your standing instructions, one per line, added to every task while the app is running. For example: "I'm a BTS SIO student", "never click Finish exam", "always answer in French". Comments (`<!-- ... -->`) are ignored: as long as you write nothing else, the file does nothing. It is re-read for every task: a change applies right away, without restarting the app. **This file is yours: neither the app nor Claude ever changes it.** A file from an older version is converted once: an `instructions.txt` becomes `instructions.md` (its `#` lines become comments, the old file goes to the Recycle Bin), and the notes Claude used to keep at the end of `instructions.md` move to `memory.md`.
- **`memory.md`**: Claude's notes, when [Persistent memory](#persistent-memory) is on.
- **The other files in the folder**, subfolders included (courses, notes, technical documentation, assignments, bibliography, sources...): Claude gets their list with every task. It treats them as more reliable than its general knowledge: it reads the ones related to the task and relies on them first. Best-read formats: `.pdf`, `.txt`, `.md`, images, code, `.csv`, `.html` (for a Word or PowerPoint file, also save it as PDF). Hidden or temporary files (`desktop.ini`, `~$...`) are ignored, as is the folder's `README.md`.
- **PDFs**: the app extracts their text in advance, page by page, into `data\context-cache\` (redone only when the PDF changes). Claude reads that text, which is fast and saves quota, and can search it. For a diagram or a scanned PDF (no text), it shows the page as an image with the `page-pdf` action. All of this uses [Poppler](https://poppler.freedesktop.org/) (see [Installation](#installation)).
- **Read-only**: Claude can read this folder, but cannot change, move, send to the Recycle Bin or run anything in it (see [Security](#security)).

Priority order: the instruction typed in the bar (for one task), then `instructions.md` (for every task), then what Claude infers from the screen.

The folder is in your Documents, outside the repository: your courses and instructions never end up on GitHub.

### Packet Tracer

You place the devices. Claude never adds, moves or deletes one: it configures each device through its **CLI** tab (one command file per device, typed into the console) and checks with `show` commands. For PCs, it uses Desktop > IP Configuration.

**Cabling**: by default Claude leaves the cables alone. Ask for it with the instruction bar, for example "connect R1 to R2 with a crossover cable" or "cable the topology like the diagram". Claude then picks the cable in the Connections bar, clicks the first device and its port, then the second device and its port, and takes a screenshot to check the link. With "Automatically Choose Connection Type", both clicks are done in one go by the `relier` action. It works the same way in normal and smooth mode. This is new and slower than cabling by hand: check the ports it picked.

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
- **Smooth mode**: the mouse glides and the text is typed at a human pace (see below; the choice is remembered)
- **Persistent memory**: Claude keeps notes from one task to the next (see below; the choice is remembered)
- **Fast control (MCP)**: Claude drives the PC through a small server kept open during the task (see below; the choice is remembered)
- **Open the Claude-Work folder**
- **Stop the current task**
- **Quit**

### Smooth mode

By default, the mouse jumps straight to its target and text appears in a flash. Turn on **Smooth mode** in the icon menu to watch what Claude does:

- **Mouse**: it glides like a hand would, along a slightly curved path, speeding up then slowing down as it reaches the target. The time grows with the distance (Fitts' law): about 0.2 s for a short hop, 0.75 s across the screen. Then a short pause before clicking. Drag and drop is slower and almost straight; the scroll wheel turns one notch at a time.
- **Typing**: one key at a time, about 9 characters per second with irregular gaps, a longer pause after a space, punctuation and Enter (which also gives a console such as Packet Tracer time to answer). A long text (a whole configuration file, for example) is typed faster so that one action never takes more than about 45 seconds.

The choice is remembered (`data/smooth.txt`) and applies at once, even in the middle of a task. Tasks take a bit longer in this mode.

### Persistent memory

By default, each task starts from scratch. Check **Persistent memory** in the icon menu to open a kind of mini session: Claude ends each task with short notes (what it learned about you, the course or the exercise, how far it got) and gets them back at the next tasks. For example, "questions 1 to 10 done" or "the course is OSPF, chapter 3".

`System-Context\memory.md`:

```
<!-- Claude's notes (persistent memory), one per line. ... -->
- The quiz is about OSPF, chapter 3
- Questions 1 to 10 done
```

- The notes go into `System-Context\memory.md`, one per line. You can read them, fix one or delete one by hand. `instructions.md` is never touched.
- **Unchecking the mode sends `memory.md` to the Recycle Bin**: the notes are gone for Claude, and you can still get them back from the bin. Checking it again starts an empty file.
- Claude cannot write in the folder, not even in `memory.md`: it ends its answer with `MEMORY: ...` lines, and the app saves them (and hides them from the result you see). That costs no extra action during the task. One note is at most 300 characters, and all notes together at most 4000: past that, new notes are no longer saved and the result says so.
- A task you stop saves no note.
- The choice is remembered (`data/memory.txt`): the notes stay after a restart of the app as long as the mode is checked.

### Fast control (MCP)

By default, every action of Claude (a click, a key, a screenshot) starts PowerShell twice: once for the safety hook, once for `outils/pc.ps1`. That costs 2 to 3 seconds per action, and a screenshot takes two steps (take it, then read it).

Check **Fast control (MCP)** in the icon menu to use `outils/mcp.ps1` instead: a small [MCP](https://modelcontextprotocol.io) server that Claude Code starts at the beginning of the task and stops at the end.

- Claude sends several actions in one call (for example: click a field, type the answer, press Enter).
- The screenshot taken after the last action comes back in the same answer.
- There is no terminal at all in this mode: Claude only gets the file tools and the `pc` tool.

It is a single PowerShell script of a few kilobytes: nothing to install, nothing running outside a task, no network port (Claude Code talks to it through its standard input and output). The actions are the same in both modes (`outils/actions.ps1`), and so are smooth mode and the protection of `System-Context`. The choice applies to the next task and is remembered (`data/mcp.txt`). The result window and the log show how long each task took, so you can compare the two modes.

Windows only for now; the macOS/Linux port keeps its `data/pc` command.

### Stopping a task

Press **Ctrl+Alt+C** again while the star is spinning, or use **Stop the current task** in the menu. A task is also stopped automatically after 20 minutes.

During a task, don't touch the mouse or keyboard: Claude uses the real ones. If another window comes to the front, it stops by itself so it doesn't type in the wrong place.

## Security

Claude is started with limited permissions (`data\settings.json`, generated at startup). It can only:

- read the screenshots;
- click, type and scroll, through `outils/pc.ps1` (no other command is allowed), or through the `pc` tool of `outils/mcp.ps1` when Fast control is on (then there is no terminal at all);
- create or edit files in `Documents\Claude-Work` (except in `System-Context`, which is read-only).

On top of that:

- **`System-Context` is read-only**, locked three times: a `deny` rule in `data\settings.json` (`Edit(...)`, which also covers Write), the hook `outils/garde.ps1` that refuses any file write in that folder, and `pc.ps1 corbeille` that refuses to touch it (or `Claude-Work`, which contains it). Claude has no way to write there: its [Persistent memory](#persistent-memory) notes are saved by the app itself.
- **Nothing is ever permanently deleted.** The hook `outils/garde.ps1` blocks `Remove-Item`, `del`, `rm`, `format`, etc. To remove a file, Claude sends it to the Recycle Bin (`pc.ps1 corbeille`).
- Its instructions forbid buying, paying, sending messages, entering passwords or bank details, and changing Windows settings. Text displayed on screen cannot override these rules.
- No web access (WebFetch and WebSearch are denied).
- Claude is started with only the tools a task needs (`Read`, `Write`, `Edit`, `Glob`, `Grep` and `PowerShell` for `pc.ps1`), without the MCP servers, connectors and skills of your account: tasks start faster and use less quota.

## Installation

Requirements: Windows 10 or 11, with PowerShell 5.1 (built into Windows). Nothing else to install besides Claude Code.

1. Install the Claude Code CLI:
   ```powershell
   irm https://claude.ai/install.ps1 | iex
   ```
2. Log in once: run `%USERPROFILE%\.local\bin\claude.exe`, choose to log in with your Claude account, then type `/exit`.
3. Copy this folder to `%USERPROFILE%\ClaudeScreen` (or anywhere else: paths are relative to the script's folder).
4. Make it start with Windows and launch it right away:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\ClaudeScreen\Installer-Demarrage.ps1"
   Start-ScheduledTask -TaskName ClaudeScreen
   ```
   The icon appears in the notification area. A scheduled task named "ClaudeScreen" restarts it 20 s after each logon, without any window. To remove it, add `-Retirer` to the first command: it removes the scheduled task and closes the app if it is running.

**PDF reading**: `Installer-Demarrage.ps1` also downloads [Poppler for Windows](https://github.com/oschwartz10612/poppler-windows) (`pdftotext`, `pdftoppm`, about 16 MB) into `outils\poppler`, only once. If that hasn't happened yet, ClaudeScreen downloads it in the background when it starts. The version is pinned and the file is rejected if its SHA-256 hash doesn't match. Without Poppler, Claude Code cannot read PDFs (it needs `pdftoppm`). To reinstall it by hand: `powershell -ExecutionPolicy Bypass -File outils\poppler.ps1`.

`Lancer.vbs` can also start it by hand (double-click), but Windows is phasing out VBScript: prefer the scheduled task.

> **Don't put the folder in `AppData`** if you install it from Claude Desktop (Microsoft Store app). Windows then redirects the files to a private Claude Desktop folder that is invisible at startup, and you get "file not found".

## Shortcuts

| Shortcut | Status |
|---|---|
| Ctrl+Alt+C | Active |
| Ctrl+Alt+Copilot key | Active |
| Ctrl+Alt+Shift+C | Active, with the instruction bar |
| Copilot key alone (Win+Shift+F23) | Reserved by Windows, usually unavailable |

Ctrl+Alt+C is global: while the app is running, other programs no longer receive it. A few use it, for example Visual Studio (the "Call Stack" window while debugging) or Photoshop ("Canvas Size"). If that bothers you, use Ctrl+Alt+Copilot or change the shortcut in `ClaudeScreen.ps1` (`$raccourcis.Enregistrer(...)`).

## Subscription and usage

- Each task uses your Claude quota: one very short Haiku call, then Sonnet or Opus. Screenshots weigh a lot; a 50-question quiz needs several dozen of them.
- If your subscription expires or the limit is reached, the task fails with a red dot and the error message. Nothing else happens.
- Without a subscription, Claude Code can also run with a pay-as-you-go API key (`ANTHROPIC_API_KEY` environment variable).

## Structure

```
ClaudeScreen.ps1    notification-area app: shortcuts, screenshot, model triage, starting Claude
Lancer.vbs          starts the app without a window (by hand)
Installer-Demarrage.ps1  installs or removes the startup scheduled task
outils/natif.cs     Windows calls (DPI, screenshot, mouse, keyboard, smooth mode, global hotkeys, active window)
outils/natif.ps1    compiles natif.cs into a DLL only once (the name changes when the source changes)
outils/actions.ps1  the PC control actions (click, type, screenshot...), shared by the two files below
outils/pc.ps1       PC control tool used by Claude: one action per call
outils/mcp.ps1      the same actions as an MCP server (Fast control): several actions per call, screenshot in the answer
outils/garde.ps1    hook that blocks permanent deletions and writes to System-Context
outils/pdf.ps1      PDF reading: text extracted in advance, page as an image (with Poppler)
outils/memoire.ps1  instructions.md (yours, never changed) and memory.md (Claude's notes, persistent memory)
outils/poppler.ps1  downloads Poppler (pinned version, verified hash) into outils/poppler (ignored by git)
outils/System-Context-README.md  user guide copied into Documents\Claude-Work\System-Context (kept up to date at each start)
data/               EVERYTHING the app generates, kept apart from the program (private, ignored by git):
  runs/<date>/        one folder per task, deleted after 30 days:
    images/             screenshot-01.png, zoom-01.png, pdf-01.png...
    prompts/            task.txt (instructions sent to Claude), triage.txt (model choice)
    responses/          task.txt, task-errors.txt, triage.txt, triage-errors.txt
    screen.json         position and scale of the captured screen
    mcp.json            with Fast control: tells Claude Code how to start outils/mcp.ps1 for this task
  context-cache/      text extracted from the System-Context PDFs (rebuilt when needed)
  log.txt             app log
  settings.json       permissions given to Claude (regenerated at each start)
  model.txt           model choice (Model menu)
  smooth.txt          smooth mode: on or off (Smooth mode menu)
  memory.txt          persistent memory: on or off (Persistent memory menu)
  mcp.txt             fast control: on or off (Fast control menu)
```

The macOS/Linux version uses exactly the same `data/` layout. Older versions kept these files at the root of the folder (`runs/`, `journal.txt`...): they are moved into `data/` automatically at startup.

Files created by Claude go to `Documents\Claude-Work`. Your instructions, Claude's notes and your context documents are in `Documents\Claude-Work\System-Context`.

Automatic cleanup: at startup and then every 6 hours, the app permanently deletes the `data\runs\` folders older than 30 days (`$JoursConserves` variable in `ClaudeScreen.ps1`). They don't go through the Recycle Bin, so the space is really freed. The log is trimmed too. Files in `Documents\Claude-Work` are never touched.

## Limitations

- Claude cannot run any program or command other than the control tool. For example, it cannot generate an image with Python, but it can write a diagram in SVG or HTML.
- Precise mouse work (cables in Packet Tracer, drag and drop) is slow and not always reliable: cabling a large topology by hand is faster, and Claude only cables when you ask.
- The Claude Code CLI must be up to date (`claude update`): the app uses recent options (`--tools`, `--effort`, `--strict-mcp-config`). With an old version, tasks fail with "unknown option".
- For websites, the Claude in Chrome extension is often more reliable: it reads the page content directly instead of going through screenshots.
- Only one screen is captured: the one the mouse is on when you press the shortcut.

## Contributing and versions

The workflow (issue → branch → PR → review → merge) is described in [CONTRIBUTING.md](CONTRIBUTING.md); the easiest way is through the [VeD Opps dashboard](https://taskf0rce.github.io/VeD_Opps/).
Versions are published automatically (the dashboard's « Nouvelle release » button): see the [releases](../../releases) and `CHANGELOG.md`.
