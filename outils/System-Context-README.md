# System-Context: Claude's standing context

This folder gives Claude information on top of what it sees on screen.
Everything is optional: if it is empty, ClaudeScreen works as usual.

## instructions.md: your standing instructions

Write one instruction per line, **above the dashed line** (`---------------------`). They are added to **every** task, as long as ClaudeScreen is running.
Comments (`<!-- ... -->`) are ignored. The file is read again for each task: you can change it at any time.

Examples:

```
I'm a BTS SIO student, SISR track. Cisco hardware, Packet Tracer 8.
For quizzes: tick the answers and click Next, but never click "Finish exam".
Always answer in French.
```

Keep the dashed line. Everything above it is yours: neither ClaudeScreen nor Claude ever changes it.

## Persistent memory

When **Persistent memory** is checked in the icon menu, Claude writes short notes **below the dashed line**
(what it learned about you, the course or the exercise, how far it got) and reads them back at the next tasks:
a kind of mini session. When you uncheck it, the notes below the line are erased, and only them.

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
2. `instructions.md`, for every task (then Claude's notes, if Persistent memory is on).
3. What Claude guesses from the screen.

## Security

Claude can **only read** this folder: it cannot modify, move, send to the Recycle Bin or run anything in it.
The one exception is Persistent memory: when it is on, Claude can add a note below the dashed line of `instructions.md`, and nothing else.
This README.md file is not sent to Claude; it is recreated if deleted.
