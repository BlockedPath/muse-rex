#!/bin/sh
# Install or update the muse-rex plugin for Muse Code. Safe to run again.
#
#   curl -fsSL https://raw.githubusercontent.com/BlockedPath/muse-rex/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/BlockedPath/muse-rex/main/install.sh | sh -s -- --uninstall
set -u
REPO=BlockedPath/muse-rex
MARKET=muse-rex
PLUGIN=rex

if [ -t 1 ]; then b='\033[1m' r='\033[0m'; else b='' r=''; fi
say() { printf "${b}muse-rex:${r} %s\n" "$*"; }
die() { say "$*" >&2; exit 1; }

# Find Muse. Meta's installer puts it in ~/.local/bin, which a piped `sh`
# may not have on PATH.
muse=$(command -v muse 2>/dev/null) || muse=""
[ -n "$muse" ] || { [ -x "$HOME/.local/bin/muse" ] && muse="$HOME/.local/bin/muse"; }
[ -n "$muse" ] || die "Muse Code isn't installed (no muse on PATH or in ~/.local/bin)."

if [ "${1:-}" = "--uninstall" ]; then
	"$muse" plugins remove "$PLUGIN" >/dev/null 2>&1 && say "removed the $PLUGIN plugin"
	"$muse" plugins marketplace remove "$MARKET" >/dev/null 2>&1 && say "removed the $MARKET marketplace"
	say "the launcher keeps its one-line icon fix until Muse next updates it"
	exit 0
fi

command -v rex >/dev/null 2>&1 ||
	say "warning: rex isn't on PATH; Muse will get its icon but no Rex session context"

# Marketplace: add it, or refresh it if it's already there.
if "$muse" plugins marketplace list 2>/dev/null | grep -q "^$MARKET[[:space:]]"; then
	"$muse" plugins marketplace update "$MARKET" >/dev/null || die "couldn't update the $MARKET marketplace"
else
	"$muse" plugins marketplace add "$MARKET" "$REPO" >/dev/null || die "couldn't add the $MARKET marketplace"
fi

# Plugin: install it, or update it in place.
if "$muse" plugins inspect "$PLUGIN" >/dev/null 2>&1; then
	"$muse" plugins update "$PLUGIN" >/dev/null 2>&1 || die "couldn't update the $PLUGIN plugin"
	say "updated the $PLUGIN plugin"
else
	"$muse" plugins install "$PLUGIN@$MARKET" >/dev/null 2>&1 || die "couldn't install $PLUGIN@$MARKET"
	say "installed the $PLUGIN plugin"
fi

# Muse won't run a third-party hook until it's trusted. The plugin has one
# SessionStart hook: hooks/session-start.sh in https://github.com/$REPO
"$muse" plugins approve "$PLUGIN" >/dev/null || die "couldn't approve the plugin's hook; run: muse plugins approve $PLUGIN"
say "trusted its SessionStart hook (see https://github.com/$REPO/blob/main/hooks/session-start.sh)"

# Fix the launcher now, so the icon shows from the very next launch.
pkg=$("$muse" plugins inspect "$PLUGIN" 2>/dev/null | sed -n 's/.*cache=\([^[:space:]]*\).*/\1/p' | head -1)
if [ -n "$pkg" ] && [ -f "$pkg/bin/fix-launcher.sh" ]; then
	sh "$pkg/bin/fix-launcher.sh" "$muse"
fi

if ! "$muse" skills list 2>/dev/null | grep -q '^rex[[:space:]]'; then
	say "tip: run 'rex skill setup' to give Muse Rex's full usage guide"
fi
say "done. Start Muse in a Rex pane."
