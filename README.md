# git-why

A Claude Code skill that captures the design reasoning behind non-trivial
commits as git notes attached to the commit itself. The "why" — rejected
alternatives, constraints that forced an approach, tradeoffs — becomes
retrievable from the terminal forever, independent of the chat that produced
it.

## Install

Clone this repo once, anywhere outside your projects, then run its installer
in one of two modes:

```bash
git clone git@github.com:pratts/git-why.git ~/work/github/git-why

# Per user: every repo you open in Claude Code
~/work/github/git-why/scripts/install-skill.sh

# Per repo: one repo only (run inside it, or pass its path)
~/work/github/git-why/scripts/install-skill.sh --project [repo-dir]
```

| | Skill | Commit-reminder hook |
| --- | --- | --- |
| Per user | `~/.claude/skills/git-why` → this clone | `~/.claude/settings.json` |
| Per repo | `<repo>/.claude/skills/git-why` → this clone | `<repo>/.claude/settings.local.json` |

Either way, git-why's files are never tracked by another repository:

- The skill is a **symlink** back to this clone, not a copy, so there's no
  nested `.git` inside your project and nothing to vendor.
- Per repo, the hook goes in `settings.local.json` (Claude Code's
  uncommitted local settings), not the shared `settings.json`, and both
  paths are added to the repo's `.git/info/exclude`, git's local-only
  ignore list. No tracked file in the repo changes, not even `.gitignore`,
  and `git add .` skips them.
- Existing settings files are merged with `jq`, never overwritten.

Pick one mode per machine-and-repo: installed both ways, Claude sees the
skill twice and the reminder fires twice (the installer warns about this).

**Update:** `git pull` in the clone. Every install links to it, so there's
nothing to re-run.

**Uninstall:** run the same command with `--uninstall` added, e.g.
`install-skill.sh --project --uninstall`. It removes the link, the hook
entry and the exclude lines it added, and leaves your other settings alone.

Requires `jq` (the installer and the hook both use it) and git.

## How it works

Claude applies this skill proactively: right after a commit that involved
real design reasoning, and whenever you ask "why does this exist" about
existing code. This only happens when Claude is present in the session —
there's no background automation beyond the reminder hook, and no retroactive
notes for commits made outside Claude. The full criteria for what warrants a
note, how to write one, and where to put it when a decision spans two files
lives in [SKILL.md](SKILL.md) — that's the canonical source Claude actually
follows; this file just covers install and the lookup tools.

The installer also registers a `PostToolUse` hook
(`hooks/git-commit-reminder.sh`), which fires that reminder
deterministically after every `git commit` instead of relying on Claude to
remember. The script itself checks whether a Bash command ran `git commit`,
including forms like `git -C dir commit`, `git -c key=value commit` and
`git --no-pager commit`, while ignoring look-alikes such as
`git log --grep=commit` or `git commit-tree`. Without `jq` it can't read the
command, so it reminds after every Bash call rather than never.

## Usage

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
