# git-why

A Claude Code skill that captures the design reasoning behind non-trivial
commits as git notes attached to the commit itself. The "why" — rejected
alternatives, constraints that forced an approach, tradeoffs — becomes
retrievable from the terminal forever, independent of the chat that produced
it.

## Install

Clone this repo into `.claude/skills/git-why/` inside the target project:

```bash
git clone <this-repo-url> .claude/skills/git-why
```

The resulting path **must** be `.claude/skills/git-why/SKILL.md`. A common
way this silently fails to load is an extra level of nesting, e.g.
`.claude/skills/git-why/git-why/SKILL.md` — double check the clone didn't
create a nested directory.

## When Claude uses this

Claude applies this skill proactively in two situations:

- Right after making a git commit that involved real design reasoning — a
  rejected alternative, a constraint that ruled out a simpler approach, a
  subtle bug fix, a deliberate tradeoff.
- Whenever you ask "why does this exist," "why was this done this way," or
  "what was the reasoning behind X" about existing code — Claude looks up the
  answer with the bundled scripts before falling back to searching old chat
  history.

This only happens when Claude is actively present in a session. There's no
hook, no background automation, and no retroactive note-writing for commits
made outside Claude (by you directly, by CI, by another tool) — if Claude
wasn't there when the commit happened, no note gets written for it
automatically.

This repo itself is an exception it opts into for its own dogfooding: it
ships an optional `PostToolUse` hook (`.claude/settings.json` +
`.claude/hooks/git-commit-reminder.sh`) that fires the reminder above
deterministically after every `git commit`, rather than relying on Claude to
remember. It only takes effect when this repo is the open project — it does
**not** travel with the skill when installed into `.claude/skills/git-why/`
elsewhere.

**Known limitation:** the hook matches on `if: "Bash(git commit *)"`, which
requires the literal words `git` and `commit` to be adjacent in the command.
A commit invoked with a git-level flag in between —
`git -c user.name=x commit -m ...`, `git -C some/other/repo commit -m ...`,
`git --no-pager commit -m ...` — won't match, so the hook silently doesn't
fire for it. Tracked in
[#2](https://github.com/pratts/git-why/issues/2).

### When a note gets written (and when it doesn't)

After making a commit, Claude writes a note if — and only if — the change
involved non-obvious reasoning. Good candidates:

- An approach was chosen specifically because a simpler one didn't work (a
  library limitation, a race condition, a platform constraint).
- An alternative was seriously considered and rejected — worth recording
  *why* it was rejected, not just that it was.
- A subtle bug fix where the root cause isn't obvious from the diff alone.
- A tradeoff was made deliberately (e.g. simplicity over performance, or
  vice versa).

It's skipped for mechanical changes: dependency bumps, formatting,
straightforward additions with no real decision behind them, typo fixes. Not
every commit needs a note — a note on every commit is noise, and noise gets
ignored.

A good note does NOT restate the commit message or summarize the diff — that
information is already in `git log`. It answers the question someone will
ask while staring at this code later: **"why is it built this way, and not
some other way?"**

Commit message: `Add per-torrent advisory lock to prevent spawn race`

Good note:
> Needed to prevent two processes racing to download into the same directory if the
> parent dies between spawning the child and recording its PID. Considered checking
> PID + boot_id alone, but that only detects the race after it's already happened.
> flock is auto-released on any process death (including SIGKILL), so it closes the
> race window itself rather than just detecting it afterward.

Bad note (just restates the commit): "Added a lock file to prevent two
processes from running at once."

Notes are written with:

```bash
git notes add -m "<reasoning text>" <commit-sha>
```

or, to add to a note that already exists on that commit rather than replace
it:

```bash
git notes append -m "<additional reasoning>" <commit-sha>
```

### Decisions spanning two files

Some decisions involve both a primitive's definition (a lock, a helper
function) and a specific call site that uses it in a particular way. The
note goes on the commit that actually makes the decision — usually the
integration/call-site commit, since the primitive itself is often
decision-agnostic (it doesn't know how it'll be used, only the caller does).

But the primitive's own file is often the first place someone looks when
they ask "why does this exist" — they're staring at the lock, not the
caller. When that's a likely lookup point, Claude also adds a short pointer
note there:

```bash
git notes add -m "See commit <sha> for why this is used this way in <caller>." <primitive-sha>
```

That way a file-scoped lookup on the primitive doesn't silently come up
empty — it at least points to where the real reasoning lives, instead of
relying on the reader to already know to check the caller's commit.

## Usage

### `scripts/git-why.sh <file> [line]`

Find the commit(s) that touched a file (or one line), and print any
reasoning note attached to them.

```bash
scripts/git-why.sh internal/process/lock.go
scripts/git-why.sh internal/process/lock.go 41
```

### `scripts/git-notes-grep.sh <keyword> [more keywords...]`

Search the text of every note in the repo for a keyword (case-insensitive,
multiple keywords are OR'd together, matched literally — special characters
in a keyword are treated as plain text, not regex).

```bash
scripts/git-notes-grep.sh lock reboot
```

This is the recall-first lookup: use it when you remember a concept but not
which file or commit it lives in. It complements `git-why.sh`, which is
navigation-first — you already know the file/line and want the reasoning
attached to it.

### `scripts/git-why-record.sh [path]`

Coverage check: report which recent commits don't have a reasoning note yet.
Purely mechanical — no AI, no note generation, just a status report of "the
gap" since notes were last kept up to date. Walks history from newest to
oldest, finds the most recent commit that already has a note, and lists
everything newer than that.

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
