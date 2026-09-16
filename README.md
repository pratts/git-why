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
multiple keywords are OR'd together).

```bash
scripts/git-notes-grep.sh lock reboot
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
