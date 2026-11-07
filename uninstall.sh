#!/usr/bin/env bash
# Removes what install.sh added. Leaves the rest of your config alone.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
CONF="$HOME/.tmux.conf"
SETTINGS="$HOME/.claude/settings.json"
HOOK="$DIR/hooks/tmux-light.sh"

if [ -f "$CONF" ]; then
  tmp=$(mktemp)
  grep -vxF "source-file $DIR/tmux.conf" "$CONF" | grep -vxF "# beautify-tmux" > "$tmp" || true
  mv "$tmp" "$CONF"
  echo "tmux: removed from $CONF"
fi

if [ -f "$SETTINGS" ] && command -v jq >/dev/null; then
  tmp=$(mktemp)
  jq --arg h "$HOOK" '
    if .hooks then
      .hooks |= (with_entries(.value |= map(select((.hooks // []) | all(.command | startswith($h) | not))))
                 | with_entries(select(.value | length > 0)))
    else . end
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "claude: hooks removed from $SETTINGS"
fi

echo "Restart tmux (tmux kill-server) to drop the old styles."
