#!/usr/bin/env bash
# Pane reminders. A reminder is the pane option @todo, kept in capitals.
#
#   tmux-remind.sh key <pane_id> <client>   Prefix + R: asks for a reminder, or
#                                           asks if the one there is done
#   tmux-remind.sh up <pane_id>             puts the pane's reminder in capitals
#   tmux-remind.sh show <client>            run by hooks on every pane, window or
#                                           session change: if any pane still has
#                                           a reminder, the status bar turns pink
#                                           and lists them all for a few seconds.
#                                           You keep typing while it shows.
#   tmux-remind.sh setup                    run once at load: teaches the status
#                                           bar to show that list
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
show)
  # every reminder still open, the current pane's too; panes in the 💤 window
  # are hidden ones, their cover already counts them
  left=()
  while IFS='|' read -r wname todo; do
    [ -z "$todo" ] || [ "$wname" = "💤" ] && continue
    left+=("${todo^^}")
  done < <(tmux list-panes -a -F '#{window_name}|#{@todo}')
  [ ${#left[@]} -eq 0 ] && exit 0
  text=$(printf '  ·  📌 %s' "${left[@]}"); text="${text:5}"
  # The list takes over the status bar for a few seconds, in pink. It is part
  # of the bar, not a popup, so keys keep going to the pane while it shows.
  id="$$.$RANDOM"
  tmux set -g @flash "STILL TO DO:  ${text//#/##}" \; set -g @flash-id "$id"
  sleep "${REMIND_SECONDS:-4}"
  # a newer list may have taken the bar meanwhile: then leave it alone
  if [ "$(tmux show -gqv @flash-id)" = "$id" ]; then tmux set -gu @flash; fi
  exit 0
  ;;
setup)
  # wraps the default status bar: while @flash is set, the bar shows it instead
  tmux set -gu status-format
  tmux set -g 'status-format[0]' \
    "#{?@flash,#[fill=colour218 bg=colour218 fg=colour16 bold align=centre]#{@flash},$(tmux show -gv 'status-format[0]')}"
  ;;
esac
