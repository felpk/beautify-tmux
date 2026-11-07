#!/usr/bin/env bash
# Sets the status light of the current tmux pane.
#
#   tmux-light.sh busy    -> 🟡
#   tmux-light.sh done    -> 🟢  (🔴 instead if the agent's last message ends in a question)
#   tmux-light.sh ask     -> 🔴
#   tmux-light.sh off     -> no light
#
# Works from any script running inside tmux. As a Claude Code hook it also
# reads the hook's JSON from stdin to spot a final question.

[ -z "$TMUX_PANE" ] && exit 0
state="$1"

if [ "$state" = done ] && [ ! -t 0 ] && command -v jq >/dev/null; then
  input="$(cat)"
  msg=$(jq -r '.last_assistant_message // empty' <<<"$input" 2>/dev/null)
  if [ -z "$msg" ]; then
    t=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)
    [ -f "$t" ] && msg=$(tail -n 200 "$t" | jq -rs '[.[]|select(.type=="assistant")|.message.content[]?|select(.type=="text")|.text]|last // ""' 2>/dev/null)
  fi
  last_line=$(printf '%s\n' "$msg" | sed '/^[[:space:]]*$/d' | tail -n 1)
  case "$last_line" in *'?'|*'?**'|*'?*') state=ask ;; esac
fi

case "$state" in
  busy) light="🟡" ;;
  done) light="🟢" ;;
  ask)  light="🔴" ;;
  off)  tmux set-option -p -u -t "$TMUX_PANE" @light 2>/dev/null; exit 0 ;;
  *)    echo "usage: $0 busy|done|ask|off" >&2; exit 1 ;;
esac

tmux set-option -p -t "$TMUX_PANE" @light "$light" 2>/dev/null
exit 0
