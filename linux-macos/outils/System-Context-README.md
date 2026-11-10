# System-Context: Claude's standing context

This folder gives Claude information on top of what it sees on screen.
Everything is optional: if it is empty, ClaudeScreen works as usual.

## instructions.md: your standing instructions

Write one instruction per line. They are added to **every** task, as long as ClaudeScreen is running.
Comments (`<!-- ... -->`) are ignored. The file is read again for each task: you can change it at any time.

Examples:

```
I'm a BTS SIO student, SISR track. Cisco hardware, Packet Tracer 8.
For quizzes: tick the answers and click Next, but never click "Finish exam".
Always answer in French.
```

This file is yours: neither ClaudeScreen nor Claude ever changes it.

## memory.md: Claude's notes (Persistent memory)

When **Persistent memory** is checked in the icon menu, Claude ends each task with short notes
(what it learned about you, the course or the exercise, how far it got). ClaudeScreen saves them in `memory.md`
and gives them back to Claude at the next tasks: a kind of mini session.

You can open `memory.md`, fix a note or remove a line. When you uncheck Persistent memory,
the file goes to the Recycle Bin (the trash on macOS and Linux), and a new empty one is created the next time you check it.

## Your documents

Drop anything that can help here: courses, notes, technical documentation, assignments, bibliography, sources...
You can create subfolders.

For each task, Claude receives the list of these files. It treats them as more reliable than its general knowledge: it reads the ones related to the task and relies on them to answer.

Formats read best: `.pdf`, `.txt`, `.md`, images (`.png`, `.jpg`), code, `.csv`, `.html`.

- **PDF**: ClaudeScreen extracts the text in advance (with page numbers), which is fast and
  saves your quota. For a diagram or a scanned PDF (no text), Claude looks at the page as an image.
- A Word or PowerPoint document? Save it as a PDF too.

## Priorities

1. The instruction typed in the small bar (Ctrl+Alt+Shift+C, or ⌃⌥⇧C on a Mac), for a single task.
2. `instructions.md`, for every task (then Claude's notes in `memory.md`, if Persistent memory is on).
3. What Claude guesses from the screen.

## Security

Claude can **only read** this folder: it cannot modify, move, send to the Recycle Bin or run anything in it.
That includes `memory.md`: Claude writes its notes in its answer, and ClaudeScreen is the one that saves them.

This README.md is ClaudeScreen's own file: it is not sent to Claude, it is recreated if deleted,
and replaced when a new version changes it (the old one goes to the Recycle Bin). Don't keep your own notes in it.
