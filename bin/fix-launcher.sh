#!/bin/sh
# Make Meta's official Muse launcher start the real binary with argv0 "muse".
#
# Rex picks a pane's icon from the program's argv0. Meta's launcher
# (~/.local/bin/muse) runs the binary as ".../muse-bin-<version>", which Rex
# doesn't recognize; packaged installs such as the AUR muse-code-bin already
# run ".../lib/muse/muse" and need nothing. This changes one line:
#
#   exec "$binary" "$@"   ->   exec -a muse "$binary" "$@"
#
# The launcher updates itself, which undoes the change; the plugin's
# SessionStart hook runs this script again, so the next launch is fixed.
# Usage: fix-launcher.sh [--quiet] [--check] [LAUNCHER]
# With no LAUNCHER it checks ~/.local/bin/muse, mise installs, and the muse
# on PATH.
quiet=0 check=0 target=""
for a in "$@"; do
	case "$a" in
	--quiet) quiet=1 ;;
	--check) check=1 ;;
	-h | --help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
	*) target=$a ;;
	esac
done
say() { [ "$quiet" = 1 ] || printf 'muse-rex: %s\n' "$*"; }

old='  exec "$binary" "$@"'
new='  exec -a muse "$binary" "$@"'

# Always check the usual install places too: ~/.local/bin and mise.
candidates="$target $HOME/.local/bin/muse $HOME/.local/share/mise/installs/http-muse/*/muse"
{
	p=$(command -v muse 2>/dev/null) && case "$p" in /*) candidates="$candidates $p" ;; esac
}

status=1 seen=" "
for l in $candidates; do
	[ -f "$l" ] || continue
	# Follow a symlink to the real file, so we replace the file, not the link.
	while [ -L "$l" ]; do
		t=$(readlink "$l")
		case "$t" in /*) l=$t ;; *) l=$(dirname "$l")/$t ;; esac
	done
	l="$(cd -P "$(dirname "$l")" 2>/dev/null && pwd)/$(basename "$l")"
	case "$seen" in *" $l "*) continue ;; esac
	seen="$seen$l "
	if grep -qxF "$new" "$l" 2>/dev/null; then
		say "$l already starts Muse as \"muse\""
		status=0
		continue
	fi
	# Only touch Meta's launcher: it names the binary muse-bin-<version>.
	if ! grep -qxF "$old" "$l" 2>/dev/null || ! grep -q 'muse-bin-' "$l" 2>/dev/null; then
		continue
	fi
	if [ "$check" = 1 ]; then
		say "$l needs fixing"
		status=0
		continue
	fi
	if [ ! -w "$l" ] || [ ! -w "$(dirname "$l")" ]; then
		say "can't write $l"
		continue
	fi
	# Write a copy and rename it over the original. Running launchers keep
	# reading the old file, and the copy keeps the original's mode.
	tmp="$l.muse-rex.$$"
	cp -p "$l" "$tmp" 2>/dev/null || continue
	awk -v old="$old" -v new="$new" '$0 == old { print new; next } { print }' "$l" >"$tmp" &&
		grep -qxF "$new" "$tmp" && mv -f "$tmp" "$l" || { rm -f "$tmp"; continue; }
	say "fixed $l"
	status=0
done
[ "$status" = 0 ] || say "no Meta Muse launcher needed fixing"
exit 0
