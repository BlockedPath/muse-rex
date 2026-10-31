#!/bin/sh
# Muse Code SessionStart hook for Rex. Works on macOS and Linux.
#
# 1. Tells Muse which Rex session and pane it is running in, with the same
#    text Rex gives Claude Code and Codex ("rex __internal session-start").
#    Prints nothing outside Rex.
# 2. Keeps Meta's Muse launcher starting the binary as "muse", so Rex shows
#    Muse's icon. The launcher updates itself and undoes the fix; running it
#    here repairs it for the next launch. Opt out with:
#      mkdir -p ~/.config/muse-rex && touch ~/.config/muse-rex/no-launcher-fix
#
# Muse reports its own working/blocked/done status to Rex (OSC 7501), so this
# plugin doesn't.
dir=$(cd "$(dirname "$0")" && pwd)
config="${XDG_CONFIG_HOME:-$HOME/.config}/muse-rex"

# Muse sends the hook payload on stdin; we don't need it.
[ -t 0 ] || cat >/dev/null 2>&1

# Muse runs hooks with an environment allowlist that drops REX_SESSION,
# REX_BLOCK and REX_SERVER. Recover them from the nearest ancestor process
# (Muse itself) that has them.
rex_env_of() {
	if [ -r "/proc/$1/environ" ]; then
		tr '\0' '\n' <"/proc/$1/environ" 2>/dev/null # Linux
	else
		ps -E -ww -o command= -p "$1" 2>/dev/null | tr ' ' '\n' # macOS
	fi | grep -E '^REX_(SESSION|BLOCK|SERVER)='
}
pid=$PPID vars=""
while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; do
	vars=$(rex_env_of "$pid")
	case "$vars" in *REX_SESSION=*) break ;; esac
	vars=""
	pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
[ -n "$vars" ] || [ -n "${REX_SESSION:-}" ] || exit 0 # not in Rex
# shellcheck disable=SC2163 # each $kv is "NAME=value"
for kv in $vars; do export "$kv"; done

# The process we found is Muse. Meta's launcher sits next to its binary
# (muse-bin-<version>), wherever it was installed: ~/.local/bin, mise, ...
exe=""
if [ -n "$vars" ]; then
	exe=$(readlink "/proc/$pid/exe" 2>/dev/null) || exe=$(ps -o comm= -p "$pid" 2>/dev/null)
fi
case "$exe" in */muse-bin-*) launcher="$(dirname "$exe")/muse" ;; *) launcher="" ;; esac
[ -f "$config/no-launcher-fix" ] ||
	sh "$dir/../bin/fix-launcher.sh" --quiet ${launcher:+"$launcher"} >/dev/null 2>&1

command -v rex >/dev/null 2>&1 || exit 0
ctx=$(rex __internal session-start --agent muse 2>/dev/null) || exit 0
[ -n "$ctx" ] || exit 0

# {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}
# JSON-escaped with awk, so jq isn't required.
printf '%s\n' "$ctx" | awk '
BEGIN { ORS = ""; print "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"" }
{
	gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, "")
	if (NR > 1) print "\\n"
	print
}
END { print "\"}}\n" }'
exit 0
