# System-Context: Claude's standing context

This folder gives Claude information on top of what it sees on screen.
Everything is optional: if it is empty, ClaudeScreen works as usual.

## instructions.md: your standing instructions

Write one instruction per line. They are added to **every** task, as long as ClaudeScreen is running.
Comments (`<!-- ... -->`) are ignored. The file is read again for each task: you can change it at any time.

Examples:

```
I'm a second-year computer science student.
For quizzes: tick the answers and click Next, but never click "Finish exam".
Always answer in English.
```

This file is yours: neither ClaudeScreen nor Claude ever changes it.

## Contexts: who you are and how to work for you

The `Contexts` folder holds one small file per context: Default, Studies, Software development, Networking,
Office productivity... One is active at a time: right-click the ClaudeScreen icon, open **Context** and pick one.
Default is used when you choose nothing.

- Edit these files freely: ClaudeScreen copies them here once and never changes them afterwards.
- Add your own: create `My job.md` in `Contexts` and write a few lines (who you are, what is usually on your
  screen, what to do when you give no instruction, what never to do). It appears in the menu.
- Remove the ones you don't need.

## memory.md: Claude's notes for the current session

Claude ends each task with short notes
(what it learned about you and your work, how far it got). ClaudeScreen saves them in `memory.md`
and gives them back to Claude at the next tasks of the same session.

You can open `memory.md`, fix a note or remove a line. When you start a **new session**
(Sessions window of the icon; a menu item on macOS and Linux), the file is emptied: the notes go with the session that ended.

## Your documents

Drop anything that can help here: courses, notes, procedures, technical documentation, templates, sources...
You can create subfolders.

For each task, Claude receives the list of these files. It treats them as more reliable than its general knowledge: it reads the ones related to the task and relies on them to answer.

Formats read best: `.pdf`, `.txt`, `.md`, images (`.png`, `.jpg`), code, `.csv`, `.html`.

- **PDF**: ClaudeScreen extracts the text in advance (with page numbers), which is fast and
  saves your quota. For a diagram or a scanned PDF (no text), Claude looks at the page as an image.
- A Word or PowerPoint document? Save it as a PDF too.
- Know-how for a piece of software (what Claude should do and avoid in it) also goes here, as a `.md` file.
  The `examples` folder of ClaudeScreen has ready-made ones (`packet-tracer.md`...): copy the ones you use here.

## Priorities

1. The instruction typed in the small bar (Ctrl+Alt+Shift+C, or ⌃⌥⇧C on a Mac), for a single task.
2. `instructions.md`, for every task (then Claude's notes in `memory.md`).
3. The active context.
4. What Claude guesses from the screen.

## Security

Claude can **only read** this folder: it cannot modify, move, send to the Recycle Bin or run anything in it.
That includes `memory.md`: Claude writes its notes in its answer, and ClaudeScreen is the one that saves them.

This README.md is ClaudeScreen's own file: it is not sent to Claude, it is recreated if deleted,
and replaced when a new version changes it (the old one goes to the Recycle Bin). Don't keep your own notes in it.
