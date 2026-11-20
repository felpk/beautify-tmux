#!/usr/bin/env bash
# Pane reminders. A reminder is the pane option @todo, kept in capitals.
#
#   tmux-remind.sh key <pane_id> <client>   Prefix + R: asks for a reminder, or
#                                           asks if the one there is done
#   tmux-remind.sh up <pane_id>             puts the pane's reminder in capitals
#   tmux-remind.sh show <client>            run by hooks on every pane, window or
#                                           session change: if other panes still
#                                           have a reminder, a box in the middle
#                                           of the screen lists them for a moment.
#                                           Any key closes it. It never stops you
#                                           from going anywhere.
# A hidden pane (Prefix + H) keeps its reminder; its 💤 cover shows it.
set -u
export LC_ALL=C.UTF-8
me="$0"

case "${1:-}" in
key)
  pane="$2"; client="$3"
  real=$(tmux show -pqv -t "$pane" @hides); target="${real:-$pane}"
  todo=$(tmux show -pqv -t "$target" @todo)
  if [ -n "$todo" ]; then
    tmux confirm-before -t "$client" -p "Done: ${todo//#/##}? (y/n)" \
      "set -pu -t $target @todo ; set -pu -t $pane @todo ; refresh-client"
  else
    tmux command-prompt -t "$client" -p "Reminder:" \
      "set -p -t $target @todo \"%%\" ; run-shell \"$me up $target\""
  fi
  ;;
up)
  todo=$(tmux show -pqv -t "$2" @todo)
  [ -n "$todo" ] && tmux set -p -t "$2" @todo "${todo^^}"
  tmux refresh-client 2>/dev/null
  ;;
show|_box)
  client="$2"
  active=$(tmux display -p -c "$client" '#{pane_id}' 2>/dev/null) || exit 0
  left=(); width=24
  # panes in the 💤 window are hidden ones: their cover already counts them
  while IFS='|' read -r id wname todo; do
    [ -z "$todo" ] || [ "$id" = "$active" ] || [ "$wname" = "💤" ] && continue
    todo="${todo^^}"; left+=("$todo")
    [ $(( ${#todo} + 8 )) -gt "$width" ] && width=$(( ${#todo} + 8 ))
  done < <(tmux list-panes -a -F '#{pane_id}|#{window_name}|#{@todo}')
  [ ${#left[@]} -eq 0 ] && exit 0
  if [ "$1" = _box ]; then
    # inside the popup: print the list, close after 3 s or on any key
    printf '\e[?25l\n'
    for t in "${left[@]}"; do printf '  \e[1;38;5;231m📌 %s\e[0m\n' "$t"; done
    read -rsn1 -t 3
    exit 0
  fi
  [ "$(tmux display -p -c "$client" '#{popup_active}' 2>/dev/null)" = 1 ] && exit 0
  tmux display-popup -c "$client" -x C -y C -w "$width" -h $(( ${#left[@]} + 4 )) \
    -T "#[align=centre bold] STILL TO DO " -S "fg=colour218" \
    -E "bash '$me' _box '$client'"
  ;;
esac
