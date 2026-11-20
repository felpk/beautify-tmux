#!/usr/bin/env bash
# Prefix + w: a menu with every pane by its title, grouped by session, with
# its status light and folder. No window or pane numbers. Enter (or a click)
# jumps to the pane. Hidden panes show up through their 💤 cover.
#
#   tmux-panes.sh <client_name>
set -u
client="${1:?client name}"
host=$(tmux display -p '#{host_short}')
esc() { printf '%s' "${1//#/##}"; }   # a literal # in a title is not a format

args=(); cur=""
# "|" splits the fields; the title goes last so a "|" inside it stays in it.
while IFS='|' read -r sess id light todo dir active wname name; do
  [ "$wname" = "💤" ] && continue
  if [ "$sess" != "$cur" ]; then
    [ -n "$cur" ] && args+=("")
    args+=("-#[fg=colour244]$(esc "$sess")" "" "")
    cur="$sess"
  fi
  # a pane nobody named only carries the host name: show its folder instead
  if [ -z "$name" ] || [ "$name" = "$host" ]; then name="$dir"; dir=""; fi
  mark="  "; [ "$active" = 1 ] && mark="▶ "
  label="$mark${light:+$light }${todo:+📌 }#[bold]$(esc "$name")#[nobold]${dir:+  #[fg=colour244]$(esc "$dir")}"
  args+=("$label" "" "switch-client -t '$id' ; select-window -t '$id' ; select-pane -t '$id'")
done < <(tmux list-panes -a -F \
  '#{session_name}|#{pane_id}|#{@light}|#{?@todo,1,}|#{b:pane_current_path}|#{&&:#{pane_active},#{&&:#{window_active},#{session_attached}}}|#{window_name}|#{?@name,#{@name},#{s/^[✳⠀-⣿] //:pane_title}}')

tmux display-menu -c "$client" -T "#[align=centre bold] Panes " -x C -y C -- "${args[@]}"
