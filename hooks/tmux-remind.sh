#!/usr/bin/env bash
# Pane reminders. A reminder is the pane option @todo, set with Prefix + R.
# Run by hooks every time you change pane, window or session: if other panes
# still have a reminder, it says which, so you don't forget them. It never
# stops you from going anywhere.
#
#   tmux-remind.sh <client_name>
set -u
client="${1:?client name}"
active=$(tmux display -p -c "$client" '#{pane_id}' 2>/dev/null) || exit 0

left=""
while IFS='|' read -r id todo; do
  [ -z "$todo" ] || [ "$id" = "$active" ] && continue
  left="${left:+$left  ·  }$todo"
done < <(tmux list-panes -a -F '#{pane_id}|#{@todo}')

[ -z "$left" ] && exit 0
# a literal # in a reminder is not a format
tmux display -c "$client" -d 4000 "📌 Still to do: ${left//#/##}"
