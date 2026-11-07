#!/usr/bin/env bash
# Installs beautify-tmux.
#   ./install.sh            tmux config only
#   ./install.sh --claude   also adds the status-light hooks to Claude Code
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
CONF="$HOME/.tmux.conf"
LINE="source-file $DIR/tmux.conf"

need() { command -v "$1" >/dev/null || { echo "beautify-tmux: '$1' not found" >&2; exit 1; }; }
need tmux

ver=$(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -n1)
if ! awk -v v="$ver" 'BEGIN { exit !(v >= 3.2) }'; then
  echo "beautify-tmux: tmux $ver found, 3.2 or newer is needed" >&2
  exit 1
fi

touch "$CONF"
if grep -qxF "$LINE" "$CONF"; then
  echo "tmux: already set up in $CONF"
else
  cp "$CONF" "$CONF.bak.$(date +%Y%m%d%H%M%S)"
  printf '\n# beautify-tmux\n%s\n' "$LINE" >> "$CONF"
  echo "tmux: added to $CONF (backup saved next to it)"
fi
chmod +x "$DIR/hooks/tmux-light.sh"

if [ "${1:-}" = "--claude" ]; then
  need jq
  SETTINGS="$HOME/.claude/settings.json"
  HOOK="$DIR/hooks/tmux-light.sh"
  mkdir -p "$(dirname "$SETTINGS")"
  [ -s "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  tmp=$(mktemp)
  jq --arg h "$HOOK" '
    def add(ev; m; arg):
      .hooks[ev] = ((.hooks[ev] // [])
        | map(select((.hooks // []) | all(.command | startswith($h) | not)))
        + [ (if m then {matcher: m} else {} end) + {hooks: [{type: "command", command: ($h + " " + arg)}]} ]);
    add("UserPromptSubmit"; null; "busy")
    | add("Stop"; null; "done")
    | add("Notification"; "permission_prompt|elicitation_dialog"; "ask")
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "claude: hooks added to $SETTINGS (backup saved next to it)"
fi

if [ -n "${TMUX:-}" ]; then
  tmux source-file "$CONF" && echo "tmux: config reloaded"
else
  echo "Start tmux, or run: tmux source-file ~/.tmux.conf"
fi
