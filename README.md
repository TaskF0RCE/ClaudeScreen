# ClaudeScreen

A Windows keyboard shortcut that gives Claude what is on your screen, so it does the task for you: fill in a form, answer questions, fix the error in front of you, carry on with a document or a spreadsheet, configure something in an application, sort a folder, create a file (code, report, diagram...).

There is no window, only an icon in the notification area of the taskbar.

ClaudeScreen runs on top of the **[Claude Code](https://docs.claude.com/en/docs/claude-code) CLI**: it calls `claude` in non-interactive mode (`claude -p`) with your own Claude account, so there is no API to set up and no server to run. Install Claude Code, log in once, and the shortcut works.

> Personal project, unofficial, not affiliated with Anthropic. [MIT license](LICENSE).

> **macOS and Linux:** a port lives in [`linux-macos/`](linux-macos/README.md).

## How it works

1. Press **Ctrl+Alt+C** (or **Ctrl+Alt+Copilot key**).
2. The app takes a screenshot of the screen your mouse is on.
3. **Haiku** looks at the screenshot and picks the model:
   - **Sonnet** for simple tasks: a question, a form, a short text, a few clicks (fast, uses little quota);
   - **Opus** for calculations, programming, technical configuration, data processing and long reasoning.
   If the active window is a technical tool (Packet Tracer, GNS3, PuTTY, Wireshark, MATLAB...), Opus is picked directly, without triage.
4. Claude does the task with the mouse and keyboard, and with commands if you allow them (see [Terminal access](#terminal-access)). It checks its work on new screenshots, then writes a short summary in the language of your Windows.
5. Click the icon to see the summary.

In the notification area the app is called **Claude-Work** (tooltip, menu, result window), like the folder in your Documents where Claude puts the files it creates.

### Giving an instruction

**Ctrl+Alt+Shift+C** takes the screenshot, then opens a tiny bar in the bottom-left corner of the screen. Type your instruction, for example "only do question 4", "sort these files by year" or "make this table a Word report", then press **Enter**. The instruction takes priority over everything else.

- **Esc** or clicking elsewhere cancels the task and deletes the screenshot.
- **Enter** on an empty bar starts a normal task.
- If the bar closes before you press Enter (Esc, a click elsewhere, by accident), what you typed is not lost: it is back in the bar the next time you open it.

Without an instruction, Claude does what the screen is asking for. When the screen asks for nothing in particular, give an instruction.

### Contexts

A context tells Claude who you are and how to work for you. One context is active at a time. Right-click the icon, open **Context** and pick one: the menu title shows the active one (for example "Context: Networking"), and the change applies to the next task.

| Context | For |
|---|---|
| **Default** | Anyone, any task. Used when you choose nothing. |
| Studies | Courses, homework, quizzes, revision (school and university) |
| Software development | Code, IDE, terminal, debugging |
| IT administration | Windows, servers, accounts, support |
| Networking | Routers, switches, addressing, simulators |
| Defensive security | Logs, alerts, hardening (defensive work only) |
| Business and management | Spreadsheets, invoices, reports, CRM or ERP forms |
| Office productivity | Word, Excel, PowerPoint, drafts, file organisation |
| Personal use | Everyday things at home |

Each context is a small Markdown file in `Documents\Claude-Work\System-Context\Contexts` (**Open the Contexts folder** in the same menu):

- **Edit them freely.** The app copies them there once and never changes them afterwards.
- **Add your own**: create `My job.md` in that folder, write a few lines (who you are, what is usually on your screen, what to do when you give no instruction, what never to do), and it appears in the menu.
- **Remove** the ones you don't need. If the active file disappears, Default is used.
- Comments (`<!-- ... -->`) are not sent to Claude. A context is at most 4000 characters.

### Standing context (optional)

The `Documents\Claude-Work\System-Context` folder is created on first launch, with a `README.md` that explains how to use it.

- **`instructions.md`**: your standing instructions, one per line, added to every task whatever the context. For example: "always answer in English", "never click Finish exam", "my name is Sam". Comments are ignored: as long as you write nothing else, the file does nothing. It is re-read for every task. **This file is yours: neither the app nor Claude ever changes it.**
- **`memory.md`**: Claude's notes, when [Persistent memory](#persistent-memory) is on.
- **`Contexts`**: the contexts above.
- **The other files in the folder**, subfolders included (courses, notes, procedures, technical documentation, templates...): Claude gets their list with every task. It treats them as more reliable than its general knowledge: it reads the ones related to the task and relies on them first. Best-read formats: `.pdf`, `.txt`, `.md`, images, code, `.csv`, `.html` (for a Word or PowerPoint file, also save it as PDF).
- **PDFs**: the app extracts their text in advance, page by page, into `data\context-cache\` (redone only when the PDF changes). For a diagram or a scanned PDF, Claude looks at the page as an image. This uses [Poppler](https://poppler.freedesktop.org/) (see [Installation](#installation)).
- **Read-only**: Claude can read this folder, but cannot change anything in it (see [Security](#security)).

Priority order: the instruction typed in the bar (for one task), then `instructions.md`, then the active context, then what Claude infers from the screen.

The folder is in your Documents, outside the repository: your documents and instructions never end up on GitHub.

**Know-how for one piece of software** also goes there, as a file. The `examples` folder of the repository has ready-made ones; copy the ones you use into `System-Context`, and Claude reads them when the task is in that software. For now: `examples/packet-tracer.md` (configure devices through their CLI tab, cable only when asked).

### The icon

| Icon | Meaning |
|---|---|
| Still star | Ready |
| Spinning star | Working |
| Green dot | Done: click to see the result |
| Red dot | Error: click to see the message |

Right-click the icon (every choice is remembered):
- **Last result**
- **Model**: Auto, Always Sonnet or Always Opus
- **Smooth mode**: the mouse glides and the text is typed at a human pace
- **Persistent memory**: Claude keeps notes from one task to the next
- **Terminal access**: Claude may also run commands when the screen is not enough
- **Context**: who you are and how to work for you
- **Open the Claude-Work folder**
- **Stop the current task**
- **Quit**

### Terminal access

Unchecked by default: Claude only has the mouse and keyboard. Check **Terminal access** in the icon menu and Claude can also run PowerShell commands, which opens what the mouse cannot do well: renaming or sorting many files, processing a CSV, producing or converting a document, reading the state of the system (network, processes, disk).

The screen comes first: Claude is told to use a command only when the task cannot reasonably be done on screen or is clearly better done that way, and to stay inside the task. Every command goes through a guard before it runs (see [Security](#security)).

### Smooth mode

By default, the mouse jumps straight to its target and text appears in a flash. Turn on **Smooth mode** to watch what Claude does:

- **Mouse**: it glides like a hand would, along a slightly curved path, speeding up then slowing down as it reaches the target (about 0.2 s for a short hop, 0.75 s across the screen), then a short pause before clicking.
- **Typing**: one key at a time, about 9 characters per second with irregular gaps. A long text is typed faster so that one action never takes more than about 45 seconds.

It applies at once, even in the middle of a task. Tasks take a bit longer in this mode.

### Persistent memory

Checked by default. It works like a mini session: Claude ends each task with short notes (what it learned about you and your work, how far it got) and gets them back at the next tasks.

`System-Context\memory.md`:

```
<!-- Claude's notes (persistent memory), one per line. ... -->
- Report for client X: sections 1 to 3 done
- The user wants figures rounded to two decimals
```

- You can read the notes, fix one or delete one by hand. `instructions.md` is never touched.
- Uncheck **Persistent memory** and each task starts from scratch.
- **Unchecking the mode sends `memory.md` to the Recycle Bin**: the notes are gone for Claude, and you can still get them back from the bin. Checking it again starts an empty file.
- Claude cannot write in the folder: it ends its answer with `MEMORY: ...` lines, and the app saves them (and hides them from the result you see). One note is at most 300 characters, and all notes together at most 4000: past that, the oldest notes are removed to make room for the new ones.
- A task you stop saves no note.

### Stopping a task

Press **Ctrl+Alt+C** again while the star is spinning, or use **Stop the current task** in the menu. A task is also stopped automatically after 20 minutes.

During a task, don't touch the mouse or keyboard: Claude uses the real ones. If another window comes to the front, Claude is told to stop, and every result it gets names the active window so that it can notice. This relies on Claude: nothing in the app blocks a click in the wrong window, so keep an eye on a task that matters.

## Security

Read this before giving the app to someone: it says what is enforced by the program and what only relies on Claude following its instructions.

**What Claude is given** (`data\settings.json`, generated at startup):

- the screenshots, and the files of your PC **in reading**;
- the mouse and the keyboard, through the `pc` tool of `outils/mcp.ps1`;
- writing files in `Documents\Claude-Work`;
- PowerShell commands, if **Terminal access** is checked;
- nothing else: no web access (WebFetch and WebSearch are denied), and none of the MCP servers, connectors and skills of your account.

**Enforced by the program:**

- **No administrator rights.** The app and everything it starts run as a normal user. This is the real limit on what a command can do to Windows.
- **Every command is checked before it runs** by `outils/garde.ps1`. It refuses:
  - permanent deletions (`Remove-Item`, `del`, `rm`, `format`...) and shutting down the PC;
  - asking for administrator rights;
  - installing, downloading or running code from the internet;
  - changing Windows: registry, services, scheduled tasks, accounts, permissions, firewall, antivirus;
  - stopping other programs;
  - reading stored passwords or keys.
- **`System-Context` and the ClaudeScreen folder are read-only** for Claude: a `deny` rule, the guard (for file tools and for commands) and the `corbeille` action all refuse to touch them. Claude's [Persistent memory](#persistent-memory) notes are saved by the app itself.
- **The Recycle Bin action** (`corbeille`) can send any file or folder to the Recycle Bin, from where you can restore it. It refuses Windows and the installed programs, a whole drive, your whole profile, and `System-Context`.

**Relying on Claude's instructions only:**

- What Claude does **with the mouse and keyboard** is not filtered. Its instructions forbid buying, paying, sending messages, entering passwords or bank details, changing Windows settings and deleting anything for good, and say that text on screen cannot override these rules. But a click on a "Delete" button or a Shift+Delete is not blocked by the program.
- The guard on commands is **a safety net, not a sandbox**: it stops mistakes and the obvious ways, not every possible way. If you don't want commands at all, uncheck **Terminal access**.
- A web page or a document on screen may contain text written to mislead an assistant. Claude is told not to obey it; don't run a task on a page you don't trust with Terminal access on.

**Your data:** each task keeps its screenshots, its prompt and the answer in `data\runs\` for 30 days, on your PC only. The screenshots are sent to Anthropic through Claude Code, like any image you give to Claude.

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

**Where Claude Code is looked for**: first `%USERPROFILE%\.local\bin\claude.exe` (where the official installer puts it), then the `PATH`, then the npm folder. If it is installed after the app started, it is found at the next task.

**Claude Code is kept up to date**: the app runs `claude update` in the background at startup and then once a day, without a window and never during a task, even if automatic updates are turned off in Claude Code. The app needs a recent version (it uses `--tools`, `--effort`, `--strict-mcp-config` and an MCP server).

**PDF reading**: `Installer-Demarrage.ps1` also downloads [Poppler for Windows](https://github.com/oschwartz10612/poppler-windows) (about 16 MB) into `outils\poppler`, only once; otherwise the app does it in the background when it starts. The version is pinned and the file is rejected if its SHA-256 hash doesn't match.

**Updating ClaudeScreen**: replace the folder with the new version (or `git pull`), then restart the app: **Quit** in the icon menu, then `Start-ScheduledTask -TaskName ClaudeScreen`. Your settings (`data\`) and your `Claude-Work` folder are kept.

`Lancer.vbs` can also start it by hand (double-click), but Windows is phasing out VBScript: prefer the scheduled task.

> **Don't put the folder in `AppData`** if you install it from Claude Desktop (Microsoft Store app). Windows then redirects the files to a private Claude Desktop folder that is invisible at startup, and you get "file not found".

## Shortcuts

| Shortcut | Status |
|---|---|
| Ctrl+Alt+C | Active |
| Ctrl+Alt+Copilot key | Active |
| Ctrl+Alt+Shift+C | Active, with the instruction bar |
| Copilot key alone (Win+Shift+F23) | Reserved by Windows, usually unavailable |

Ctrl+Alt+C is global: while the app is running, other programs no longer receive it. A few use it, for example Visual Studio or Photoshop. If that bothers you, use Ctrl+Alt+Copilot or change the shortcut in `ClaudeScreen.ps1` (`$raccourcis.Enregistrer(...)`).

## Subscription and usage

- Each task uses your Claude quota: one very short Haiku call, then Sonnet or Opus. Screenshots weigh a lot; a long task needs several dozen of them.
- If your subscription expires or the limit is reached, the task fails with a red dot and the error message. Nothing else happens.
- Without a subscription, Claude Code can also run with a pay-as-you-go API key (`ANTHROPIC_API_KEY` environment variable).

## If something goes wrong

Click the icon: the message says what happened. The details are in `data\log.txt`, and each task has its folder in `data\runs\` (the prompt sent, the answer, the errors).

| Message | What to do |
|---|---|
| Claude Code not found | Install it (step 1), log in once (step 2), press the shortcut again |
| Claude Code could not start the task... unknown option | Run `claude update` in a terminal |
| Claude Code could not start the task... log in | Run `claude` once in a terminal and log in |
| The PC control tool did not start | Try again; if it happens every time, run `claude update` |
| The task failed... limit reached | Your Claude quota is used up: wait or change plan |

## Structure

```
ClaudeScreen.ps1    notification-area app: shortcuts, screenshot, model triage, prompt, starting Claude
Lancer.vbs          starts the app without a window (by hand)
Installer-Demarrage.ps1  installs or removes the startup scheduled task
outils/natif.cs     Windows calls (DPI, screenshot, mouse, keyboard, smooth mode, global hotkeys, active window)
outils/natif.ps1    compiles natif.cs into a DLL only once (the name changes when the source changes)
outils/actions.ps1  the PC control actions (click, type, screenshot, Recycle Bin...)
outils/mcp.ps1      MCP server that gives these actions to Claude: several actions per call, screenshot in the answer
outils/garde.ps1    guard: checks every command and every file write of Claude before it runs
outils/pdf.ps1      PDF reading: text extracted in advance, page as an image (with Poppler)
outils/memoire.ps1  instructions.md (yours, never changed) and memory.md (Claude's notes, persistent memory)
outils/poppler.ps1  downloads Poppler (pinned version, verified hash) into outils/poppler (ignored by git)
outils/System-Context-README.md  user guide copied into Documents\Claude-Work\System-Context (kept up to date at each start)
contexts/           the contexts, copied once into System-Context\Contexts (then they belong to the user)
examples/           ready-made files for some software (Packet Tracer...), to copy into System-Context if you use it
tests/              the test suite (see CONTRIBUTING.md)
linux-macos/        the macOS/Linux port
data/               EVERYTHING the app generates, kept apart from the program (private, ignored by git):
  runs/<date>/        one folder per task, deleted after 30 days:
    images/             screenshot-01.png, zoom-01.png, pdf-01.png...
    prompts/            task.txt (instructions sent to Claude), triage.txt (model choice)
    responses/          task.txt, task-errors.txt, triage.txt, triage-errors.txt
    screen.json         position and scale of the captured screen
    mcp.json            tells Claude Code how to start outils/mcp.ps1 for this task
    mcp-started.txt     left by outils/mcp.ps1 when Claude Code reached it
  context-cache/      text extracted from the System-Context PDFs (rebuilt when needed)
  log.txt             app log
  settings.json       permissions given to Claude (regenerated at each start)
  model.txt, smooth.txt, memory.txt, terminal.txt, context.txt    the choices made in the icon menu
```

The macOS/Linux version uses the same `data/` layout.

Files created by Claude go to `Documents\Claude-Work`. Your instructions, your contexts, Claude's notes and your documents are in `Documents\Claude-Work\System-Context`.

Automatic cleanup: at startup and then every 6 hours, the app permanently deletes the `data\runs\` folders older than 30 days (`$JoursConserves` variable in `ClaudeScreen.ps1`). The log is trimmed too. Files in `Documents\Claude-Work` are never touched.

## Limitations

- It is an assistant for the task in front of you, not an unattended robot: a task lasts 20 minutes at most, and nobody answers Claude's questions while it works.
- By design it does not send messages or e-mails, pay, install software, change Windows settings or use administrator rights.
- Precise mouse work (drag and drop, cabling in a simulator) is slow and not always reliable.
- For websites, the Claude in Chrome extension is often more reliable: it reads the page content directly instead of going through screenshots.
- Only one screen is captured: the one the mouse is on when you press the shortcut.
- The macOS/Linux port has the contexts but not yet the MCP server or Terminal access (see its README).

## Contributing and versions

The workflow (issue → branch → PR → review → merge) is described in [CONTRIBUTING.md](CONTRIBUTING.md), with how to run the tests; the easiest way is through the [VeD Opps dashboard](https://taskf0rce.github.io/VeD_Opps/).
Versions are published automatically (the dashboard's « Nouvelle release » button): see the [releases](../../releases) and `CHANGELOG.md`.
