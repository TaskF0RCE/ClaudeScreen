# ClaudeScreen

A Windows keyboard shortcut that gives Claude what is on your screen, so it does the task for you: fill in a form, answer questions, fix the error in front of you, carry on with a document or a spreadsheet, configure something in an application, sort a folder, create a file (code, report, diagram...).

There is no window, only an icon in the notification area of the taskbar.

ClaudeScreen runs on top of the **[Claude Code](https://docs.claude.com/en/docs/claude-code) CLI**: it calls `claude` in non-interactive mode (`claude -p`) with your own Claude account, so there is no API to set up and no server to run. Install Claude Code, log in once, and the shortcut works.

> Personal project, unofficial, not affiliated with Anthropic. [MIT license](LICENSE).

> **macOS and Linux:** a port lives in [`linux-macos/`](linux-macos/README.md).

## How it works

1. Put the task on screen and press a shortcut. The app takes a screenshot of the screen your mouse is on.
   - **Ctrl+Alt+C** (or **Ctrl+Alt+Copilot key**): a tiny bar opens, and you type what you want Claude to do.
   - **Ctrl+Alt+Shift+C**: automatic. You type nothing, Claude works the task out from the screen and your context.
2. Either shortcut, pressed again during a task, stops it.
3. **Haiku** looks at the screenshot and picks the model:
   - **Sonnet** for simple tasks: a question, a form, a short text, a few clicks (fast, uses little quota);
   - **Opus** for calculations, programming, technical configuration, data processing and long reasoning.
   If the active window is a technical tool (Packet Tracer, GNS3, PuTTY, Wireshark, MATLAB...), Opus is picked directly, without triage.
4. Claude does the task with the mouse and keyboard, and with commands if you allow them (see [Terminal access](#terminal-access)). It checks its work on new screenshots, then writes a short summary in the language of your Windows.
5. Click the icon to see the summary.

In the notification area the app is called **Claude-Work** (tooltip, menu, result window), like the folder in your Documents where Claude puts the files it creates.

### The two shortcuts

**Ctrl+Alt+C: you say what to do.** It takes the screenshot, then opens a tiny bar in the bottom-left corner of the screen. Type your instruction, for example "only do question 4", "sort these files by year" or "make this table a Word report", then press **Enter**. The instruction takes priority over everything else.

- **Esc** or clicking elsewhere cancels the task and deletes the screenshot.
- **Enter** on an empty bar starts an automatic task, like the other shortcut.
- If the bar closes before you press Enter (Esc, a click elsewhere, by accident), what you typed is not lost: it is back in the bar the next time you open it.

**Ctrl+Alt+Shift+C: automatic.** No bar: Claude starts at once and does not act at random. It works out what is expected from your standing instructions, the roles of the session, its notes of the session, the documents of the session and your other documents, and the most recent files of `Claude-Work`, then from the screen. If all of that still does not say what to do, it changes nothing and tells you what it would need.

The Sessions window reminds you of both shortcuts whenever it has no task to show.

### Roles

A role tells Claude who you are and how to work for you, for example **Network engineer** or **Professor**. Each session has its own roles, one or more. Tick them with the **Roles** button of the Sessions window, or in the icon menu (**Roles: ...**, for the session in use). A change applies to the next task of that session.

Roles go with their session: resuming a session brings its roles back, and a new session starts with the roles of the one before it.

| Role | For |
|---|---|
| **General assistant** | Anyone, any task. Used when no other role is ticked. |
| Professor | Lessons, exercises and tests to prepare, grading (school and university) |
| Software developer | Code, IDE, terminal, debugging |
| IT administrator | Windows, servers, accounts, support |
| Network engineer | Routers, switches, addressing, simulators |
| Security analyst | Logs, alerts, hardening (defensive work only) |
| Business professional | Spreadsheets, invoices, reports, CRM or ERP forms |
| Office assistant | Word, Excel, PowerPoint, drafts, file organisation |

With several roles ticked, Claude works in all of them (for example Professor and Network engineer to prepare a networking course). The roles are part of Claude's instructions for every task of the session. They come after your standing instructions (`instructions.md`) and never replace them.

Each role is a small Markdown file in `Documents\Claude-Work\System-Context\Roles`. **Open the Roles folder** is at the bottom of the roles menu.

- **Edit them freely.** The app copies them there once and never changes them afterwards.
- **Add your own**: create `Accountant.md` in that folder and write a few lines: who you are, what is usually on your screen, what to do when you give no instruction, what never to do. It then appears in the menu.
- **Remove** the ones you don't need. A role whose file is gone is left out.
- Comments (`<!-- ... -->`) are not sent to Claude. A role is at most 4000 characters: past that, its end is not sent, and the result of the task says so.

**Coming from a version before 1.0:** the contexts become roles at the first start.

- The context that was active becomes the role of the session in use (Networking → Network engineer, Office productivity → Office assistant...). Studies and Personal use have no role: a session that used them gets General assistant.
- A context file that you wrote or changed is kept as a role with the same name.
- The old `Contexts` folder goes to the Recycle Bin.

### Standing context (optional)

The `Documents\Claude-Work\System-Context` folder is created on first launch, with a `README.md` that explains how to use it.

- **`instructions.md`**: your standing instructions, one per line, added to every task whatever the session and its roles. For example: "always answer in English", "never click Finish exam", "my name is Sam". Comments are ignored: as long as you write nothing else, the file does nothing. It is re-read for every task. **This file is yours: neither the app nor Claude ever changes it.** At most 4000 characters are sent: past that, the result of the task tells you that the end was left out. Put long texts in another file of the folder instead.
- **`memory.md`**: Claude's notes for the current session (see [Sessions and memory](#sessions)).
- **`Roles`**: the roles above.
- **`Session documents`**: the documents you gave to each session (see [Sessions](#sessions)). Manage them from the Sessions window.
- **The other files in the folder**, subfolders included (courses, notes, procedures, technical documentation, templates...): Claude gets their list with every task, whatever the session. It treats them as more reliable than its general knowledge: it reads the ones related to the task and relies on them first. Best-read formats: `.pdf`, `.txt`, `.md`, images, code, `.csv`, `.html` (for a Word or PowerPoint file, also save it as PDF).
- **PDFs**: the app extracts their text in advance, page by page, into `data\context-cache\` (redone only when the PDF changes). For a diagram or a scanned PDF, Claude looks at the page as an image. This uses [Poppler](https://poppler.freedesktop.org/) (see [Installation](#installation)).
- **Read-only**: Claude can read this folder, but cannot change anything in it (see [Security](#security)).

Priority order:

1. the instruction typed in the bar (for one task);
2. `instructions.md`;
3. the roles of the session;
4. Claude's notes and the documents of the session;
5. the other documents;
6. what Claude infers from the screen.

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
- **Sessions**: the answer of the last task (a click on the icon does the same), or what Claude has said and done so far while a task is running. It also holds your earlier sessions, a new session, the choice between Persisted Memory and Ghost Mode, the roles and documents of each session, how long sessions are kept, and **Delete session** (see [Sessions](#sessions))
- **Model**: Auto, Always Sonnet or Always Opus
- **Smooth mode**: the mouse glides and the text is typed at a human pace
- **Terminal access**: Claude may also run commands when the screen is not enough
- **Roles**: the roles of the session in use; the menu title shows them, for example "Roles: Network engineer" (see [Roles](#roles))
- **Open the Claude-Work folder**
- **Quit**

### Terminal access

Unchecked by default: Claude only has the mouse and keyboard. Check **Terminal access** in the icon menu and Claude can also run PowerShell commands (the first time, the app explains what this allows and asks you to confirm; after one Yes it does not ask again), which opens what the mouse cannot do well: renaming or sorting many files, processing a CSV, producing or converting a document, reading the state of the system (network, processes, disk).

The screen comes first: Claude is told to use a command only when the task cannot reasonably be done on screen or is clearly better done that way, and to stay inside the task. Every command goes through a guard before it runs (see [Security](#security)).

### Smooth mode

By default, the mouse jumps straight to its target and text appears in a flash. Turn on **Smooth mode** to watch what Claude does:

- **Mouse**: it glides like a hand would, along a slightly curved path, speeding up then slowing down as it reaches the target (about 0.2 s for a short hop, 0.75 s across the screen), then a short pause before clicking.
- **Typing**: one key at a time, about 9 characters per second with irregular gaps. A long text is typed faster so that one action never takes more than about 45 seconds.

It applies at once, even in the middle of a task. Tasks take a bit longer in this mode.

### Sessions

A **session** is a run of tasks that belong together, like the exercises of one assignment. Inside a session, Claude ends each task with short notes (what it learned about you and your work, how far it got) and gets them back at the next task, so it does not start from scratch or read the same document again.

Everything about sessions is in one window: **Sessions** in the icon menu, or a click on the icon. It is small and sits in the bottom-right corner; drag its border to resize it, and the size is remembered, even after a restart (`data\window.txt`). It cannot be made too small to use, and **Default size** appears when the size is not the normal one, to bring it back.

- **The drop-down list** holds your sessions: the one in use first, then the earlier ones, newest first. Each one shows its name (see below), its date and its number of tasks. Pick one to read it.
- **The `<` `>` arrows** go through the tasks of the chosen session, with the instruction you typed, the answer and the steps. The newest task is the last one (3 / 3). While a task is running, the last entry shows what Claude has said and done so far.
- **New session** starts again from nothing, in the mode that is selected. Use it when you move on to something unrelated.
- **Resume** goes back to an earlier session: it becomes the current one again, Claude gets the notes it had, and the next tasks are added to it.
- **Roles** shows the roles of the chosen session. Click it to tick or untick some (see [Roles](#roles)).
- **Documents (n)** holds the documents of the chosen session: open one, remove one, or add some (see below).

**Names.** You have nothing to do: a session gets its name on its own.

- After its first finished task, Claude Haiku names the session from what the task was about, like the title of a conversation ("OSPF lab on R1 and R2", "Dupont client report").
- This runs in the background and never delays anything.
- Until the name arrives, the session is named by its number and date (Session 3 - 17/11/2026 14:05).
- If Haiku fails, answers something that is not a name, or takes more than 90 seconds, that name stays. Haiku tries again after the next task, 3 times at most.
- A ghost session is never named: nothing of it is sent for that.

**Documents of a session.** Give a session the files it is about: an assignment, a course, a procedure, specifications, instructions in Markdown...

- **Add documents...** copies files into the session; the originals are not touched. They are kept in `System-Context\Session documents\<session>\`.
- Claude gets them with every task of that session, reads the ones related to the task and relies on them first.
- They come on top of your standing instructions and of the other files of `System-Context`, never instead of them.
- They go with the session: resuming it brings them back, and a new session starts without any.
- **Remove** sends a document to the Recycle Bin.

A session is in one of two modes, chosen right under the list:

- **Persisted Memory** (the default): the session is kept, with its notes, name, roles and documents. Its tasks stay in the list for the time chosen at the bottom of the window, and you can resume it.
- **Ghost Mode**: nothing is kept, like a private window in a browser.
  - The session only lives in the memory of the app: its notes, its results and its roles are never written anywhere.
  - The folder of each task (screenshots, instruction, answer, steps) is deleted for good when the task ends.
  - You can still read the tasks of the ghost session in the window while it lasts.
  - It starts with the roles of the session you were in. Changing them does not change that session.
  - The documents you add to it are copies, deleted for good when it ends, or at the next start if the app was closed.

Going from one mode to the other:

- **Ghost Mode stays on** as long as it is selected, even after a restart. **New session** then starts another ghost session and forgets the previous one.
- **Selecting Persisted Memory** forgets the ghost session and puts you back in the session you had before, as it was. **New session** then creates a kept session.
- **Resume** on a session of the list always selects Persisted Memory.
- None of this can be done while a task is running.

Ghost Mode does not hide the files that Claude creates for you in `Claude-Work`, and the task still goes through your Claude account like any other.

**How long sessions are kept.** The bottom of the window shows how long persisted sessions are kept: 7 days, **30 days** (the default), 90 days or 1 year.

- The choice applies at once, to every persisted session, and is kept in `data\retention.txt`.
- A task older than that is deleted (screenshots, instruction, answer).
- A session goes away with its last task, along with its notes, its name and its roles. Its documents go to the Recycle Bin.
- A session that has documents but no task stays as long as its documents were added within that time.
- Ghost Mode keeps nothing, whatever this choice.

**Delete session**, next to that choice, deletes the session shown, right away, after a question. Use it when Claude learned something wrong in a session and you don't want it to come back.

- Everything the session left goes to the Recycle Bin, in one folder named after it (`ClaudeScreen - deleted session ...`): its tasks (screenshots, instructions, answers, steps), Claude's notes, its name, its roles, its documents, and the transcripts Claude Code kept of its tasks (in `%USERPROFILE%\.claude\projects`). You can restore it from there; Claude never sees any of it again.
- The other sessions are not touched.
- Deleting the session in use replaces it with a new, empty session that has the same roles.
- On **Earlier tasks**, it deletes the tasks from before sessions existed.
- On the ghost session, it only forgets it: nothing of it was written anywhere.
- It cannot be done while a task is running.
- Claude Code never keeps a transcript of the one-word triage or of the session name: only the task itself has one, and not in Ghost Mode.

About the notes:

- The notes of the current session are in `System-Context\memory.md`, one per line. You can read them, fix one or delete one by hand. `instructions.md` is never touched. The notes of the other sessions wait in `data\sessions\`, and go away with the last task of their session.
- Claude cannot write in the folder: it ends its answer with `MEMORY: ...` lines, and the app saves them (and hides them from the result you see). One note is at most 300 characters, and all notes together at most 4000: past that, the oldest notes are removed to make room for the new ones.
- A task you stop saves no note.
- To never keep any note, write `never` in `data\memory.txt` and restart the app.

### Stopping a task

Press **Ctrl+Alt+C** (or **Ctrl+Alt+Shift+C**) again while the star is spinning. A task is also stopped automatically after 20 minutes, and when you quit the app.

Nothing is lost when a task stops: **Sessions** then lists what Claude had said and done before the stop. To see where a task is without stopping it, click the icon.

Each result is kept in the folder of its task (`data\runs\<date>\result.txt`), next to its screenshots, and goes away with it after the time chosen in the Sessions window (30 days by default).

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
- **`System-Context` and the ClaudeScreen folder are read-only** for Claude: a `deny` rule, the guard (for file tools and for commands) and the `corbeille` action all refuse to touch them. Claude's [notes](#sessions) notes are saved by the app itself.
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
3. Download **`ClaudeScreen-Setup.exe`** from the [latest release](https://github.com/TaskF0RCE/ClaudeScreen/releases/latest) and run it. It copies the app to `%USERPROFILE%\ClaudeScreen`, makes it start with Windows and starts it: the icon appears in the notification area.

   The file is not signed (a certificate costs money), so Windows may show "Windows protected your PC": click **More info**, then **Run anyway**. It asks for no administrator rights and writes only in that folder.

A scheduled task named "ClaudeScreen" restarts the app 20 s after each logon, without any window. To remove it:
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\ClaudeScreen\Installer-Demarrage.ps1" -Retirer
```
It removes the scheduled task and closes the app if it is running. The folder itself stays: delete it yourself if you want.

**Without the Setup** (from a copy of this repository, with `git clone` or the ZIP): put the folder where you want (paths are relative to the script's folder), then:
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\ClaudeScreen\Installer-Demarrage.ps1"
Start-ScheduledTask -TaskName ClaudeScreen
```

**Where Claude Code is looked for**: first `%USERPROFILE%\.local\bin\claude.exe` (where the official installer puts it), then the `PATH`, then the npm folder. If it is installed after the app started, it is found at the next task.

**Claude Code is kept up to date**: the app runs `claude update` in the background at startup and then once a day, without a window and never during a task, even if automatic updates are turned off in Claude Code. The app needs a recent version (it uses `--tools`, `--effort`, `--strict-mcp-config` and an MCP server).

**PDF reading**: `Installer-Demarrage.ps1` also downloads [Poppler for Windows](https://github.com/oschwartz10612/poppler-windows) (about 16 MB) into `outils\poppler`, only once; otherwise the app does it in the background when it starts. The version is pinned and the file is rejected if its SHA-256 hash doesn't match.

**Updating ClaudeScreen**: run the `ClaudeScreen-Setup.exe` of the new release. It replaces the app, restarts it, and keeps your settings (`data\`) and your `Claude-Work` folder. With a git copy: `git pull`, then **Quit** in the icon menu and `Start-ScheduledTask -TaskName ClaudeScreen`.

`Lancer.vbs` can also start it by hand (double-click), but Windows is phasing out VBScript: prefer the scheduled task.

> **Don't put the folder in `AppData`** if you install it from Claude Desktop (Microsoft Store app). Windows then redirects the files to a private Claude Desktop folder that is invisible at startup, and you get "file not found".

## Shortcuts

| Shortcut | Status |
|---|---|
| Ctrl+Alt+C | Active: the instruction bar |
| Ctrl+Alt+Copilot key | Active: the instruction bar |
| Ctrl+Alt+Shift+C | Active: automatic task |
| Copilot key alone (Win+Shift+F23) | Reserved by Windows, usually unavailable |

Both shortcuts are global: while the app is running, other programs no longer receive them. A few use it, for example Visual Studio or Photoshop. If that bothers you, use Ctrl+Alt+Copilot or change the shortcut in `ClaudeScreen.ps1` (`$raccourcis.Enregistrer(...)`).

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
Lancer.lnk          starts the app by hand through its scheduled task
Lancer.vbs          starts the app without a window (by hand, older way: Windows is phasing out VBScript)
Installer-Demarrage.ps1  installs or removes the startup scheduled task
outils/natif.cs     Windows calls (DPI, screenshot, mouse, keyboard, smooth mode, global hotkeys, active window)
outils/natif.ps1    compiles natif.cs into a DLL only once (the name changes when the source changes)
outils/actions.ps1  the PC control actions (click, type, screenshot, Recycle Bin...)
outils/mcp.ps1      MCP server that gives these actions to Claude: several actions per call, screenshot in the answer
outils/garde.ps1    guard: checks every command and every file write of Claude before it runs
outils/pdf.ps1      PDF reading: text extracted in advance, page as an image (with Poppler)
outils/memoire.ps1  instructions.md (yours, never changed) and memory.md (Claude's notes, persistent memory)
outils/deroule.ps1  the steps of a task (what Claude said and did), read from the stream Claude Code writes
installer/          Setup.cs and Build-Setup.ps1: build ClaudeScreen-Setup.exe (attached to each release)
outils/poppler.ps1  downloads Poppler (pinned version, verified hash) into outils/poppler (ignored by git)
outils/System-Context-README.md  user guide copied into Documents\Claude-Work\System-Context (kept up to date at each start)
roles/              the roles, copied once into System-Context\Roles (then they belong to the user)
examples/           ready-made files for some software (Packet Tracer...), to copy into System-Context if you use it
tests/              the test suite (see CONTRIBUTING.md)
linux-macos/        the macOS/Linux port
data/               EVERYTHING the app generates, kept apart from the program (private, ignored by git):
  runs/<date>/        one folder per task, deleted after the time chosen in the Sessions window (30 days by default):
    images/             screenshot-01.png, zoom-01.png, pdf-01.png...
    prompts/            task.txt (instructions sent to Claude), triage.txt (model choice)
    responses/          task.jsonl (what Claude said and did, step by step), task-errors.txt, triage.txt, triage-errors.txt
    result.txt          what you were shown at the end, with the steps (Sessions window)
    session.txt, instruction.txt    the session of the task, and the instruction typed for it
    screen.json         position and scale of the captured screen
    mcp.json            tells Claude Code how to start outils/mcp.ps1 for this task
    mcp-started.txt     left by outils/mcp.ps1 when Claude Code reached it
  context-cache/      text extracted from the System-Context PDFs (rebuilt when needed)
  log.txt             app log
  settings.json       permissions given to Claude (regenerated at each start)
  model.txt, smooth.txt, terminal.txt, ghost.txt    the choices made in the icon menu and in the Sessions window
  retention.txt           how long persisted sessions are kept, in days (30 when absent)
  window.txt              the size of the Sessions window, when you changed it
  session.txt             the id of the current session (each task folder holds the id of its own)
  sessions/               per session: <id>.title.txt (its name), <id>.roles.txt (its roles), <id>.md (its notes, when not current)
  terminal-accepted.txt   you answered Yes to the Terminal access question (delete it to be asked again)
```

The macOS/Linux version uses the same `data/` layout.

Files created by Claude go to `Documents\Claude-Work`. Your instructions, your roles, Claude's notes, your documents and those of each session are in `Documents\Claude-Work\System-Context`.

Automatic cleanup: at startup and then every 6 hours, the app permanently deletes the `data\runs\` folders older than the time chosen in the Sessions window (30 days by default). The documents of an expired session go to the Recycle Bin. The log is trimmed too. The other files in `Documents\Claude-Work` are never touched.

## Limitations

- It is an assistant for the task in front of you, not an unattended robot: a task lasts 20 minutes at most, and nobody answers Claude's questions while it works.
- By design it does not send messages or e-mails, pay, install software, change Windows settings or use administrator rights.
- Precise mouse work (drag and drop, cabling in a simulator) is slow and not always reliable.
- For websites, the Claude in Chrome extension is often more reliable: it reads the page content directly instead of going through screenshots.
- Only one screen is captured: the one the mouse is on when you press the shortcut.
- The macOS/Linux port has the Sessions window, the roles, the session documents and the MCP server, but no Terminal access (see its README). It has not been tried on as many machines as the Windows version.

## Contributing and versions

The workflow (issue → branch → PR → review → merge) is described in [CONTRIBUTING.md](CONTRIBUTING.md), with how to run the tests; the easiest way is through the [VeD Opps dashboard](https://taskf0rce.github.io/VeD_Opps/).
Versions are published automatically (the dashboard's « Nouvelle release » button): see the [releases](../../releases) and `CHANGELOG.md`.
