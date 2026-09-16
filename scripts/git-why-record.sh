#!/usr/bin/env bash
# Usage: git-why-record.sh [path]
#
# Coverage check, not a lookup: walks commit history from newest to oldest
# and reports every commit newer than the most recent one that already has a
# reasoning note attached -- "the gap" since notes were last kept up to date.
#
# Purely mechanical: no AI, no note generation, no side effects. Answers "are
# we behind on notes?" -- distinct from git-why.sh ("what's the reasoning for
# this file/line?") and git-notes-grep.sh ("which commit has a note about
# this concept?").
#
# With no argument, walks the whole current branch. Pass a path to scope the
# walk to commits touching that file/directory instead.

set -euo pipefail

path="${1:-}"
max_print=20

shas=()
if [[ -n "$path" ]]; then
  while IFS= read -r sha_line; do
    shas+=("$sha_line")
  done < <(git log --format='%H' -- "$path")
else
  while IFS= read -r sha_line; do
    shas+=("$sha_line")
  done < <(git log --format='%H')
fi

if [[ ${#shas[@]} -eq 0 ]]; then
  echo "no commit history found${path:+ for $path}"
  exit 0
fi

gap=()
last_noted=""
for sha in "${shas[@]}"; do
  if git notes show "$sha" >/dev/null 2>&1; then
    last_noted="$sha"
    break
  fi
  gap+=("$sha")
done

if [[ -z "$last_noted" ]]; then
  echo "no notes found in this repo's history -- nothing to compare against"
  exit 0
fi

if [[ ${#gap[@]} -eq 0 ]]; then
  echo "up to date -- the newest commit already has a reasoning note"
  echo "0 commits since the last note"
  exit 0
fi

printed=0
for sha in "${gap[@]}"; do
  if [[ "$printed" -ge "$max_print" ]]; then
    break
  fi
  echo "${sha:0:9}  $(git log -1 --format=%s "$sha")"
  printed=$((printed + 1))
done

total=${#gap[@]}
if [[ "$total" -gt "$max_print" ]]; then
  echo "... and $((total - max_print)) more not shown"
fi

echo
echo "$total commits since the last note (last noted: ${last_noted:0:9} -- $(git log -1 --format=%s "$last_noted"))"
