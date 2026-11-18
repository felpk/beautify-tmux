#!/usr/bin/env bash
# Hides a pane without stopping it. Bound to Prefix + H in tmux.conf.
#
#   tmux-hide.sh <pane_id>
#
# On a normal pane: the pane moves to a background window called 💤 and a
# cover takes its place in the layout. The cover keeps the pane's title and
# status light, so you still see 🟢 or 🔴 when it finishes or asks something.
# On a cover: brings the hidden pane back.
# Closing the cover (Prefix + x) also closes the hidden pane.
set -u

if [ "${1:-}" = _cover ]; then
  real="$2"; me="$TMUX_PANE"
  gone() { ! tmux display -p -t "$real" '' >/dev/null 2>&1; }
  stop() {
    # still hidden (not brought back) -> close it together with the cover
    if [ "$(tmux display -p -t "$real" '#{window_name}' 2>/dev/null)" = "💤" ]; then
      tmux kill-pane -t "$real"
    fi
    exit 0
  }
  trap stop HUP TERM INT
  printf '\e[?25l\e[2J\e[H'
  printf '\n  \e[1m💤 Hidden.\e[0m\n  Still running.\n\n  \e[38;5;244mPrefix + H shows it.\n  Prefix + x closes it.\e[0m\n'
  while :; do
    gone && exit 0
    name=$(tmux display -p -t "$real" '#{?@name,#{@name},#{s/^[✳⠀-⣿] //:pane_title}}')
    tmux set -p -t "$me" @name "💤 $name"
    light=$(tmux show -pqv -t "$real" @light)
    if [ -n "$light" ]; then tmux set -p -t "$me" @light "$light"; else tmux set -pu -t "$me" @light; fi
    sleep 2 & wait $!
  done
fi

pane="${1:?pane id}"
real=$(tmux show -pqv -t "$pane" @hides)
if [ -n "$real" ]; then
  tmux swap-pane -d -s "$pane" -t "$real"
  tmux select-pane -t "$real"
  tmux kill-pane -t "$pane"
else
  dir=$(tmux display -p -t "$pane" '#{pane_current_path}')
  cover=$(tmux new-window -d -P -F '#{pane_id}' -n "💤" -c "$dir" "$0 _cover $pane")
  tmux set -p -t "$cover" @hides "$pane"
  tmux swap-pane -d -s "$pane" -t "$cover"
  tmux select-pane -t "$cover"
fi
