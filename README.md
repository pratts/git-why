# git-why

Record *why* a commit was made, as a git note on the commit itself, so the
reasoning outlives the chat or the memory that produced it. Works the same
whether an AI agent or you made the commit, with Claude Code, Codex, Antigravity,
Cursor or no AI tool at all.

## Quick start

Two ways to use it. Either one works alone; use both if you like.

| | Works for | Needs |
| --- | --- | --- |
| **A. Git hook** | any tool, and you at a terminal | symlink into a repo's `.git/hooks` |
| **B. Skill** | Claude Code, Codex, Antigravity, Cursor, in any repo, no hook | one symlink per tool, once per machine |

```bash
git clone git@github.com:pratts/git-why.git ~/git-why
```

### A. Git hook (any tool, any editor)

```bash
cd your-repo
ln -s ~/git-why/hooks/post-commit .git/hooks/post-commit
```

After any commit with no note:

- **You, at a terminal:** it asks `why this change? (enter to skip)`. Type one
  line, or press Enter. It gives up after 30s.
- **An AI agent (no terminal):** it prints a one-line reminder with the exact
  `git notes append -m "..."` command. The agent decides whether the change
  deserves a note ([INSTRUCTIONS.md](INSTRUCTIONS.md) has the criteria).

For a non-Claude agent, paste or reference [INSTRUCTIONS.md](INSTRUCTIONS.md)
from its rules file.

`GIT_WHY=0 git commit ...` silences it once; `GIT_WHY_PROMPT=0` keeps the
reminder but never prompts. It is skipped during rebase and cherry-pick.

**If the repo already has a post-commit hook**, the symlink would clash, so add
one line to the end of the existing hook instead (before any `exit`/`exec`):

```bash
"$HOME/git-why/hooks/post-commit"
```

**If the repo uses husky, pre-commit or anything that sets `core.hooksPath`**,
git ignores `.git/hooks`. Add that same line to the tool's own `post-commit`
file (e.g. `.husky/post-commit`). If you can't or don't want to touch the hooks,
use option B instead; the hook is optional.

Things to know:

- **Moving or deleting the clone** breaks the symlink, and the hook then stops
  running silently. Re-run the `ln -s` after moving it.
- **Commits from a GUI or IDE button** have no terminal, so there's no prompt;
  only the reminder goes to stderr, which you usually won't see. Use the
  terminal (or `git notes append`) for those.
- **One setup for every repo (optional):**
  `git config --global core.hooksPath ~/git-why/hooks`. Tradeoff: git then
  ignores each repo's own `.git/hooks`, which breaks tools like husky or
  pre-commit. The per-repo symlink doesn't have that problem.
- Needs only `git` and `bash` (3.2+ is fine, so macOS works).

### B. Skill (no hook needed)

Claude Code, Codex CLI, Antigravity and Cursor all load skills from a folder
containing `SKILL.md`, which is what this repo already is. Link it once into
each tool you use:

| Tool | Command |
| --- | --- |
| Claude Code | `ln -s ~/git-why ~/.claude/skills/git-why` |
| Codex CLI | `mkdir -p ~/.codex/skills && ln -s ~/git-why ~/.codex/skills/git-why` |
| Antigravity (app and `agy`) | `mkdir -p ~/.gemini/config/skills && ln -s ~/git-why ~/.gemini/config/skills/git-why` |
| Cursor | `mkdir -p ~/.cursor/skills && ln -s ~/git-why ~/.cursor/skills/git-why` |

Start a new session in the tool, then check it sees the skill by asking
"do you have a skill named git-why?". Headless checks:

```bash
codex exec "Do you have a skill named git-why?"
agy --settings '{"permissions":{"allow":["read_file(*)"]}}' -p='Do you have a skill named git-why?'
```

The agent then checks, after every commit it makes, whether the change
deserves a note, and answers "why does this exist" from existing notes. It
doesn't wait for a hook, so this works in repos that already have their own
post-commit hooks. The hook (A) just adds a reminder as a backup, and a prompt
for your own commits. [INSTRUCTIONS.md](INSTRUCTIONS.md) is the canonical
instructions; `SKILL.md` is only the trigger that points to it.

Skill folder locations are from each tool's docs and were checked in Codex CLI,
`agy` and the Cursor app; they can change between versions.

**A tool with no skills support** (Aider, Windsurf, Copilot, Gemini CLI, ...):
use the hook (A), and paste or reference [INSTRUCTIONS.md](INSTRUCTIONS.md) from
the tool's rules file (`AGENTS.md`, `GEMINI.md`, `CONVENTIONS.md`,
`.windsurf/rules`, `.github/copilot-instructions.md`). Not tested.

### Using it with AI agents

- **Commit with `GIT_WHY_PROMPT=0`.** Some agents run commands in a terminal, so
  the hook's question would wait on input nobody answers. `INSTRUCTIONS.md` tells
  agents to do this; the reminder still prints.
- **Sandboxes can block commits and notes.** Codex's default `workspace-write`
  sandbox and `agy`'s sandbox make `.git` read-only, so `git commit` and
  `git notes append` fail with `index.lock: Operation not permitted`. Approve
  the command when asked, or allow writes to `.git` (for Codex,
  `--sandbox danger-full-access` for a trusted repo). In non-interactive runs
  such as `codex exec`, nothing can be approved, so the commit fails.

### Reading and adding notes

Add a note any time: `git notes append -m "why" [sha]`. Read them with
`git log --show-notes` or the lookup scripts in `scripts/` (see below).
Notes aren't pushed by default; see
[the caveat below](#caveat-notes-dont-travel-with-pushfetchclone-by-default).

## Lookup scripts

Run these from inside the repo you're asking about, using the path to your
clone (e.g. `~/git-why/scripts/git-why.sh`). The examples below use the short
`scripts/...` form.

### `scripts/git-why.sh <file> [line]`

Find the commit(s) that touched a file (or one line), and print any
reasoning note attached to them. Navigation-first: use it when you already
know the file.

```bash
scripts/git-why.sh internal/process/lock.go
scripts/git-why.sh internal/process/lock.go 41
```

### `scripts/git-notes-grep.sh <keyword> [more keywords...]`

Search every note's text for a keyword (case-insensitive, OR'd together,
matched literally). Recall-first: use it when you remember a concept but not
which file it lives in.

```bash
scripts/git-notes-grep.sh lock reboot
```

### `scripts/git-why-record.sh [path]`

Coverage check: report which recent commits don't have a reasoning note yet.
Purely mechanical, no AI — just how many commits have piled up since the
last note. It counts the tail only: un-noted commits older than the most
recent note aren't included, so it isn't a total-coverage number.

```bash
scripts/git-why-record.sh
scripts/git-why-record.sh internal/process/lock.go
```

## Caveat: notes don't travel with push/fetch/clone by default

`git notes` live on a separate ref, `refs/notes/commits`, which is **not**
included in a normal `git push`, `git fetch`, or `git clone`.

For a solo project this doesn't matter. But the moment a project is shared
or cloned onto another machine, notes must be explicitly pushed and fetched,
or they will silently not show up for a collaborator:

```bash
git push origin refs/notes/commits
git fetch origin refs/notes/commits:refs/notes/commits
```

This is the single most likely thing to confuse someone the first time
notes don't appear after a clone — if you're setting this up on a shared
repo, make sure everyone knows to run the fetch command above.

## License

MIT — see [LICENSE](LICENSE).
