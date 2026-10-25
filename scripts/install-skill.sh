#!/usr/bin/env bash
# Install git-why for Claude Code, either for every repo or for one repo,
# without git-why's files ever being tracked by another repository.
#
# Usage:
#   scripts/install-skill.sh                         # per user, all repos
#   scripts/install-skill.sh --project [repo-dir]    # one repo (default: .)
#   scripts/install-skill.sh [--project [repo-dir]] --uninstall
#
# Both modes link the skill back to this clone rather than copying it, so a
# `git pull` here updates every install, and both register the
# commit-reminder hook (hooks/git-commit-reminder.sh):
#
#   per user   ~/.claude/skills/git-why -> this clone
#              hook in ~/.claude/settings.json
#   --project  <repo>/.claude/skills/git-why -> this clone
#              hook in <repo>/.claude/settings.local.json (Claude Code's
#              uncommitted local settings, not the shared settings.json)
#              both paths added to the repo's .git/info/exclude, git's local
#              ignore list, so the repo never tracks them and no tracked
#              file (not even .gitignore) changes.
#
# Settings files are merged with jq, never overwritten; re-running doesn't
# add a second hook entry, and --uninstall removes only what this added.
#
# Requires: jq; git for --project.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
hook_cmd="\"$root/hooks/git-commit-reminder.sh\""
user_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

mode=user
project_dir=
uninstall=0
while [ $# -gt 0 ]; do
	case $1 in
	--project)
		mode=project
		if [ $# -gt 1 ] && [[ $2 != --* ]]; then
			project_dir=$2
			shift
		fi
		;;
	--uninstall) uninstall=1 ;;
	-h | --help)
		sed -n '2,/^set -e/p' "$0" | sed '$d; s/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "unknown argument: $1 (see --help)" >&2
		exit 2
		;;
	esac
	shift
done

command -v jq >/dev/null || {
	echo "jq is required" >&2
	exit 1
}

if [ "$mode" = user ]; then
	base=$user_dir
	settings=$user_dir/settings.json
else
	project_dir=$(cd "${project_dir:-.}" && pwd -P)
	git -C "$project_dir" rev-parse --git-dir >/dev/null 2>&1 || {
		echo "$project_dir is not a git repository" >&2
		exit 1
	}
	if [ "$project_dir" = "$root" ]; then
		echo "refusing to install git-why into its own clone" >&2
		exit 1
	fi
	base=$project_dir/.claude
	settings=$base/settings.local.json
	exclude=$(git -C "$project_dir" rev-parse --path-format=absolute --git-path info/exclude)
fi
link=$base/skills/git-why

# --- settings.json helpers -------------------------------------------------

has_hook() {
	[ -f "$settings" ] &&
		jq -e --arg c "$hook_cmd" '[.hooks.PostToolUse[]?.hooks[]?.command] | index($c) != null' "$settings" >/dev/null
}

write_settings() { # jq filter, applied to the current file (or {})
	local tmp
	tmp=$(mktemp)
	if [ -f "$settings" ]; then jq --arg c "$hook_cmd" "$1" "$settings" >"$tmp"; else jq -n --arg c "$hook_cmd" "$1" >"$tmp"; fi
	mv "$tmp" "$settings"
}

add_hook() {
	mkdir -p "$(dirname "$settings")"
	write_settings '.hooks.PostToolUse = ((.hooks.PostToolUse // []) +
		[{matcher: "Bash", hooks: [{type: "command", command: $c}]}])'
}

remove_hook() {
	write_settings '
		.hooks.PostToolUse |= (map(.hooks |= map(select(.command != $c)))
		                       | map(select((.hooks | length) > 0)))
		| if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end
		| if .hooks == {} then del(.hooks) else . end'
	# A settings.local.json this script created and nothing else uses: remove it.
	if [ "$mode" = project ] && [ "$(jq -c . "$settings")" = "{}" ]; then
		rm "$settings"
	fi
}

# --- .git/info/exclude helpers (--project only) ----------------------------

exclude_patterns=("/.claude/skills/git-why" "/.claude/settings.local.json")

add_excludes() {
	mkdir -p "$(dirname "$exclude")"
	touch "$exclude"
	local p
	for p in "${exclude_patterns[@]}"; do
		grep -qxF "$p" "$exclude" || echo "$p" >>"$exclude"
	done
}

remove_excludes() {
	[ -f "$exclude" ] || return 0
	local p tmp
	for p in "${exclude_patterns[@]}"; do
		# settings.local.json may still hold other local settings; keep it
		# excluded unless this script just deleted the file.
		if [ "$p" = "/.claude/settings.local.json" ] && [ -f "$settings" ]; then continue; fi
		tmp=$(mktemp)
		grep -vxF "$p" "$exclude" >"$tmp" || true
		mv "$tmp" "$exclude"
	done
}

# --- uninstall -------------------------------------------------------------

if [ "$uninstall" -eq 1 ]; then
	if [ -L "$link" ]; then
		rm "$link"
		echo "Removed skill link $link"
	elif [ -e "$link" ]; then
		echo "$link is not a symlink; leaving it alone" >&2
	fi
	if has_hook; then
		remove_hook
		echo "Removed commit-reminder hook from $settings"
	fi
	if [ "$mode" = project ]; then
		remove_excludes
		# Drop .claude/skills and .claude if this left them empty.
		rmdir "$base/skills" "$base" 2>/dev/null || true
	fi
	exit 0
fi

# --- install ---------------------------------------------------------------

if [ -L "$link" ]; then
	current=$(cd "$link" 2>/dev/null && pwd -P) || current=
	if [ "$current" != "$root" ]; then
		echo "$link already points to ${current:-a missing path}; run with --uninstall first" >&2
		exit 1
	fi
	echo "Skill already linked: $link"
elif [ -e "$link" ]; then
	echo "$link already exists and is not a symlink (an older copied install?); move it aside first" >&2
	exit 1
else
	mkdir -p "$(dirname "$link")"
	ln -s "$root" "$link"
	echo "Linked skill: $link -> $root"
fi

if has_hook; then
	echo "Hook already registered in $settings"
else
	add_hook
	echo "Registered commit-reminder hook in $settings"
fi

if [ "$mode" = project ]; then
	add_excludes
	echo "Excluded from git via $exclude"
fi

# Installed both ways, Claude sees two git-why skills and the hook fires twice.
if [ "$mode" = project ] && [ -L "$user_dir/skills/git-why" ]; then
	echo "warning: git-why is also installed per user ($user_dir/skills/git-why); uninstall one of them" >&2
fi
echo "Start a new Claude Code session to pick it up."
