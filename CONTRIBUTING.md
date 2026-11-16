# Contributing

This guide explains how we work as a team without stepping on each other's toes. Every step can be done in **three ways**, from the simplest to the most technical:

- 📊 **Dashboard**: https://taskf0rce.github.io/VeD_Opps/ (buttons, nothing to install; its interface is in French)
- 🖥️ **GitHub Desktop**: https://desktop.github.com (the app that copies the code to your PC)
- 🧑‍💻 **VS Code** (or the terminal, if you like it)

Pick the one you prefer. The result is the same.

---

## The idea in 30 seconds

```
  Issue          Branch               PR                 Review           Merge          Release
 (the task) → feature/my-task → (merge request) → (someone else reads) → (into main) → (v0.2.0)
```

1. **`main` is always stable**: it is the version that works. Nobody **ever** pushes to it directly.
2. **One task = one issue = one branch** (`feature/...` for something new, `fix/...` for a fix).
3. When it's ready, open a **pull request (PR)**: "here are my changes, I propose adding them to `main`".
4. **Another member reviews** and approves. You always review other people's code, never your own.
5. When CI is green ✅ and the PR is approved 👍, you **merge**.
6. From time to time, you publish a **release**: the version number is computed automatically.

---

## 1. Create the task

### 📊 Dashboard (recommended)

Click **＋ Nouvelle feature** (new feature), pick the project, the type (feature or fix) and a name, for example "login page".

In one click, the dashboard creates:
- the **issue** "login page", assigned to you,
- the **branch** `feature/login-page`,
- a **draft PR** "feat: login page", linked to the issue,
- the cards on the **kanban**, in the "En cours" (in progress) column.

### On github.com

1. **Issues** tab → **New issue** → the "✨ Feature" or "🐛 Bug" form.
2. In the issue, right-hand column → **Development** → **Create a branch**. Name it `feature/login-page`.

---

## 2. Get the branch on your PC

> The first time only, you need to **clone** the project (copy it to your PC).
> GitHub Desktop: **File → Clone repository** → *GitHub.com* tab → pick `TaskF0RCE/the-project`.
> VS Code: **Ctrl+Shift+P** → `Git: Clone` → *Clone from GitHub*.

### 🖥️ GitHub Desktop
1. **Fetch origin**, the button at the top right.
2. **Current branch** → pick `feature/login-page`.

### 🧑‍💻 VS Code
1. Click the **branch name** at the bottom left (often `main`).
2. Pick `origin/feature/login-page`.

### Terminal
```bash
git fetch
git switch feature/login-page
```

✅ Check that you are on **your** branch before coding, not on `main`.

---

## 3. Code and save (commit)

A **commit** is a snapshot of your work with a short message. Commit often: one commit per small step that works.

### 🖥️ GitHub Desktop
1. On the left, tick the changed files.
2. At the bottom left, write a summary: `add the login form`.
3. **Commit to feature/login-page**.

### 🧑‍💻 VS Code
1. **Source Control** icon (3rd on the left, or **Ctrl+Shift+G**).
2. **+** next to the files to include, write the message, then **✓ Commit**.

### Terminal
```bash
git add .
git commit -m "add the login form"
```

> 💡 Intermediate commit messages are free-form. Only the **PR title** matters for the version (see [Conventional Commits](#conventional-commits-pr-titles)).

---

## 4. Send it to GitHub (push)

Until you push, your work only exists on your PC.

- 🖥️ **GitHub Desktop**: **Push origin** button at the top.
- 🧑‍💻 **VS Code**: **Sync Changes** button (or **⋯ → Push**).
- **Terminal**: `git push`

**CI** then runs on its own on your PR: it checks that the code builds, that the tests pass and that the PowerShell scripts have no errors.

---

## 5. Ask for a review

When your task is done and CI is green:

- 📊 **Dashboard**: **Pull requests** tab → your PR → **Prête pour review** (ready for review). The other members are notified automatically and the card moves to "En review".
- **github.com**: open your PR → **Ready for review**, then right-hand column → **Reviewers** → pick the other members.

Remember to fill in the PR description: what it changes and how to test it.

---

## 6. Review other people's code

The **Pull requests** tab of the dashboard shows at the top what **you** need to review.

1. Open the PR on GitHub → **Files changed** tab to see the changes.
2. Click the **+** next to a line to leave a comment.
3. Finish with **Review changes**:
   - **Approve** ✅ if it's good (or the dashboard's **Approuver** button),
   - **Request changes** ✋ if something needs fixing,
   - **Comment** 💬 for a simple question.

**A good review:**
- stays kind and precise: "this case crashes if the list is empty, right?" rather than "this is wrong";
- asks questions when you don't understand, that counts too;
- doesn't demand perfection: does it work, and is it readable?

If you are asked for changes: fix them on your branch, commit, push. The PR updates by itself.

---

## 7. Merge

When CI is green ✅ **and** the PR is approved 👍:

- 📊 **Dashboard**: **Merger** (merge) button. It stays greyed out while something is missing, and hovering it tells you what.
- **github.com**: **Squash and merge** button at the bottom of the PR.

All the commits of the branch become **a single commit** on `main`, with the PR title. The branch is deleted, the issue is closed and the kanban card moves to "Fini" (done).

**Then go back to `main` and update it** before the next task:
- 🖥️ GitHub Desktop: **Current branch → main**, then **Fetch origin → Pull origin**.
- 🧑‍💻 VS Code: branch name at the bottom left → `main`, then **Sync Changes**.
- Terminal: `git switch main && git pull`

---

## 8. Publish a version (release)

When several features are merged and you want to "freeze" a version:

1. 📊 Dashboard → **🏷 Nouvelle release** (new release) → pick the project.
2. A minute later, a PR **"chore(main): release 0.2.0"** appears: it contains the new version and the CHANGELOG.
3. Approve it, then **Merger**.
4. The `v0.2.0` release is published on GitHub and visible in the dashboard's **Historique** (history) tab.

Without the dashboard: the repo's **Actions** tab → **Release** → **Run workflow**.

---

## Tests

Run them before you push; CI runs the same ones on every PR.

```powershell
powershell -ExecutionPolicy Bypass -File tests\Run-Tests.ps1
python tests\test_linux_macos.py
```

- They are safe to run on your own PC: every scenario gets its own copy of the app and its own fake "Documents" in a temporary folder. Nothing touches your real folders, nothing is clicked or typed, and Claude is never called. One check takes a screenshot (kept in the temporary folder, then deleted); `-SansEcran` skips it.
- `tests\scenarios\*.ps1`: each one runs the real `ClaudeScreen.ps1` in a sandbox and checks what it did (an upgrade from an old version, a first start, the contexts and the menu, Terminal access, the Claude Code update, the steps of a task, the sessions and Ghost Mode...). `-Seul upgrade` runs only one.
- `tests\guard.ps1`: the commands the guard must allow and the ones it must block. **If you touch `outils\garde.ps1`, add your cases there.**
- `tests\mcp-server.ps1`: the MCP server, driven like Claude Code drives it.
- `tests\setup.ps1`: builds `ClaudeScreen-Setup.exe` (`installer\Build-Setup.ps1`) and installs it silently into a temporary folder, without starting anything. The whole install, with the scheduled task, only runs in the CI (`-SetupComplet`): on your PC it would replace your own ClaudeScreen task.
- `tests\test_linux_macos.py`: the logic of the macOS/Linux version with fake system modules, and its MCP server (`outils/mcp.py`) driven like Claude Code drives it; it runs on Windows too.
- What the tests cannot cover: a real task on a real screen. After a change to the prompt or to the actions, try a real task before you ask for a review.

The prompt sent to Claude exists twice (`ClaudeScreen.ps1` and `linux-macos/claude_screen.py`): change both.

## Conventional Commits (PR titles)

Every PR title starts with a **type**. It decides the next version:

| PR title | For… | Effect on the version |
| --- | --- | --- |
| `feat: add the profile page` | a new feature | 0.1.0 → **0.2.0** |
| `fix: fix the crash at startup` | a bug fix | 0.1.0 → **0.1.1** |
| `feat!: change the save format` | a breaking change | **1.0.0 → 2.0.0** (after 1.0.0) |
| `docs: explain the installation` | documentation | no new version |
| `refactor: simplify the score computation` | reorganising code without changing behaviour | no new version |
| `test: add the cart tests` | tests | no new version |
| `chore: update dependencies` | maintenance | no new version |

You can name a part of the project in parentheses: `fix(api): …`, `feat(ui): …`.
A badly formed title turns CI red, with an example of how to fix it. Edit the PR title and you're good to go.

---

## Common problems

<details>
<summary><b>CI is red ❌</b></summary>

In the PR, click **Details** next to the red check to read the error. Fix it on your branch, commit, push: CI runs again by itself.
If it's the **"titre conventionnel"** (conventional title) check, just edit the PR title (**Edit** button next to the title).
</details>

<details>
<summary><b>"This branch has conflicts"</b></summary>

`main` changed while you were working, and you both changed the same lines.

- **github.com**: **Resolve conflicts** button in the PR (for simple cases).
- 🖥️ **GitHub Desktop**: on your branch, **Branch → Update from main**, open the conflicting files, keep the right code, then commit and push.
- 🧑‍💻 **VS Code**: open the files marked **!**, choose *Accept Current / Incoming / Both*, then commit and push.

The `<<<<<<<`, `=======` and `>>>>>>>` markers delimit the two versions: they must be removed.
</details>

<details>
<summary><b>I coded on <code>main</code> by mistake</b></summary>

Don't panic, as long as you haven't pushed:
- 🖥️ **GitHub Desktop**: **Current branch → New branch**. Desktop offers to bring your changes along (*Bring my changes*).
- **Terminal**: `git switch -c feature/my-thing`. Your uncommitted changes follow you.

If you already pushed to `main`, tell the team: the "garde-fou main" (main guard) check will be red.
</details>

<details>
<summary><b>The "Merger" button is greyed out</b></summary>

Hover it: the dashboard tells you what is missing (CI not green, not approved yet, still a draft, conflict, invalid title…).
</details>

<details>
<summary><b>Update my branch with main</b></summary>

- **github.com**: **Update branch** button in the PR.
- 🖥️ GitHub Desktop: **Branch → Update from main**.
- Terminal: `git fetch && git merge origin/main`
</details>

---

## Glossary

| Word | Meaning |
| --- | --- |
| **Repo** | The project folder on GitHub, with its whole history. |
| **Branch** | A copy of the code where you work without touching `main`. |
| **Commit** | A snapshot of changes, with a message. |
| **Push / Pull** | Send your commits to GitHub / get the others' commits. |
| **PR (pull request)** | The request to add a branch into `main`. That's where you discuss and review. |
| **Review** | Reading another member's code. |
| **Merge** | Adding the changes of a PR into `main`. |
| **CI** | The automatic checks (build, tests, lint) run by GitHub Actions. |
| **Release** | A published version (e.g. `v0.2.0`), with the list of changes. |
| **SemVer** | The `MAJOR.MINOR.PATCH` version numbering. |
