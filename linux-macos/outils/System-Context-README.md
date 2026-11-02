# System-Context: Claude's standing context

This folder gives Claude information on top of what it sees on screen.
Everything is optional: if it is empty, ClaudeScreen works as usual.

## instructions.txt: your standing instructions

Write one instruction per line. They are added to **every** task, as long as ClaudeScreen is running.
Lines starting with `#` are ignored. The file is read again for each task: you can change it at any time.

Examples:

```
I'm a BTS SIO student, SISR track. Cisco hardware, Packet Tracer 8.
For quizzes: tick the answers and click Next, but never click "Finish exam".
Always answer in French.
```

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
2. `instructions.txt`, for every task.
3. What Claude guesses from the screen.

## Security

Claude can **only read** this folder: it cannot modify, move, send to the Recycle Bin or run anything in it.
This README.md file is not sent to Claude; it is recreated if deleted.
