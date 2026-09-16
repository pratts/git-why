#!/usr/bin/env bash
# Usage: git-why.sh <file> [line]
#
# Finds the commit(s) that touched a file (or one specific line, if given)
# and prints the reasoning note attached to each one, if any.
#
# git log/blame answer "what changed and when" -- this answers "why".

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: git-why.sh <file> [line]" >&2
  exit 1
fi

file="$1"
line="${2:-}"

if [[ -n "$line" ]]; then
  sha=$(git blame -L "${line},${line}" --porcelain -- "$file" 2>/dev/null | head -1 | cut -d' ' -f1)
  if [[ -z "$sha" ]]; then
    echo "could not blame ${file}:${line} -- check the file and line number" >&2
    exit 1
  fi
  shas=("$sha")
else
  shas=()
  while IFS= read -r sha_line; do
    shas+=("$sha_line")
  done < <(git log --format='%H' -- "$file")
  if [[ ${#shas[@]} -eq 0 ]]; then
    echo "no history found for $file -- check the path" >&2
    exit 1
  fi
fi

found=0
for sha in "${shas[@]}"; do
  note=$(git notes show "$sha" 2>/dev/null || true)
  if [[ -n "$note" ]]; then
    found=1
    echo "commit ${sha:0:9} -- $(git log -1 --format=%s "$sha")"
    echo "$note" | sed 's/^/  /'
    echo
  fi
done

if [[ "$found" -eq 0 ]]; then
  target="$file"
  [[ -n "$line" ]] && target="${file}:${line}"
  echo "no reasoning note found for $target"
fi
