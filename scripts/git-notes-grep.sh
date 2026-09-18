#!/usr/bin/env bash
# Usage: git-notes-grep.sh <keyword> [more keywords...]
#
# Searches the text of every commit's reasoning note for the given
# keyword(s) (case-insensitive, OR'd together, matched literally -- regex
# metacharacters in a keyword are escaped, not interpreted) and prints
# matching commits, newest first.
#
# Recall-first lookup: use this when you remember a concept ("locking",
# "port exhaustion", "reboot") but not which file or commit it lives in.
# Complements git-why.sh, which is navigation-first (you already know the
# file/line and want the reasoning attached to it).
#
# Built on `git notes list`, which enumerates only the commits that actually
# have a note attached. Cost scales with how many notes exist, not with how
# many commits the repo has -- it does not walk the full commit history and
# fork `git notes show` once per commit.

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: git-notes-grep.sh <keyword> [more keywords...]" >&2
  exit 1
fi

# Escape ERE metacharacters so keywords match literally. No `declare -A` /
# `mapfile` here on purpose -- see the note on 8af5907 (macOS ships bash 3.2,
# which has neither).
escape_regex() {
  local s="$1" out="" c i
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      '.'|'*'|'['|']'|'^'|'$'|'+'|'?'|'('|')'|'{'|'}'|'|'|'\')
        out+="\\$c" ;;
      *)
        out+="$c" ;;
    esac
  done
  printf '%s' "$out"
}

pattern=""
for kw in "$@"; do
  escaped=$(escape_regex "$kw")
  pattern="${pattern:+${pattern}|}${escaped}"
done

# git notes list prints "<note-blob-sha> <commit-sha>" pairs, one per noted
# commit. Note content is read here, once, and carried through in
# match_note -- not re-fetched later just to print it.
match_ts=()
match_sha=()
match_note=()
while read -r note_blob commit_sha; do
  [[ -z "$commit_sha" ]] && continue
  note=$(git show "$note_blob" 2>/dev/null || true)
  if [[ -n "$note" ]] && grep -qiE "$pattern" <<<"$note"; then
    match_ts+=("$(git log -1 --format=%ct "$commit_sha")")
    match_sha+=("$commit_sha")
    match_note+=("$note")
  fi
done < <(git notes list)

# git notes list order is the note tree's order, not commit date order.
# Sort match indices by timestamp so results still come out newest first,
# same as git-why.sh and git-why-record.sh.
found=0
if [[ ${#match_sha[@]} -gt 0 ]]; then
  order=""
  for (( i = 0; i < ${#match_sha[@]}; i++ )); do
    order+="${match_ts[i]} ${i}"$'\n'
  done
  while read -r _ts idx; do
    [[ -z "$idx" ]] && continue
    found=1
    echo "commit ${match_sha[idx]:0:9} -- $(git log -1 --format=%s "${match_sha[idx]}")"
    echo "${match_note[idx]}" | sed 's/^/  /'
    echo
  done < <(printf '%s' "$order" | sort -rn)
fi

if [[ "$found" -eq 0 ]]; then
  echo "no notes matched: $*"
fi
