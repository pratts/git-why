#!/usr/bin/env bash
# Usage: git-notes-grep.sh <keyword> [more keywords...]
#
# Searches the text of every commit's reasoning note for the given
# keyword(s) (case-insensitive, OR'd together) and prints matching commits.
#
# Recall-first lookup: use this when you remember a concept ("locking",
# "port exhaustion", "reboot") but not which file or commit it lives in.
# Complements git-why.sh, which is navigation-first (you already know the
# file/line and want the reasoning attached to it).

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: git-notes-grep.sh <keyword> [more keywords...]" >&2
  exit 1
fi

pattern=$(IFS='|'; echo "$*")

found=0
while read -r sha; do
  note=$(git notes show "$sha" 2>/dev/null || true)
  if [[ -n "$note" ]] && echo "$note" | grep -qiE "$pattern"; then
    found=1
    echo "commit ${sha:0:9} -- $(git log -1 --format=%s "$sha")"
    echo "$note" | sed 's/^/  /'
    echo
  fi
done < <(git log --format='%H')

if [[ "$found" -eq 0 ]]; then
  echo "no notes matched: $*"
fi
