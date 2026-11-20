#!/usr/bin/env bash
# Gives every pane its own faint background tint, so two panes side by side
# never look like one block. The tint follows the pane's place in the window
# (pane 0 bluish, pane 1 greenish, ...), so neighbours always differ.
# The active pane keeps its tint too (it doesn't go black when you click it);
# it shows bright white text, the others fade.
#
#   tmux-tint.sh            -> retint every pane on the server
#   set -g @tint 0          -> turn tints off (back to one shared background)

tints=("#1b2233" "#1d2b1f" "#2b1d2b" "#2d271a" "#1a2b2b" "#2d1c1c")
# Same hues, a touch lighter, for the active pane.
active=("#232b3e" "#253428" "#352535" "#373021" "#223535" "#372424")

focus=$(tmux show -gv @focus 2>/dev/null)
tint=$(tmux show -gv @tint 2>/dev/null)
[ "$focus" = 1 ] && fg="fg=colour236," || fg=""

tmux list-panes -a -F '#{pane_id} #{pane_index}' | while read -r id idx; do
  if [ "$tint" = 0 ]; then
    tmux set -pu -t "$id" window-style
    tmux set -pu -t "$id" window-active-style
  else
    n=$((idx % ${#tints[@]}))
    tmux set -p -t "$id" window-style "${fg}bg=${tints[n]}"
    tmux set -p -t "$id" window-active-style "fg=colour255,bg=${active[n]}"
  fi
done
