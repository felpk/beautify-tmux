#!/usr/bin/env bash
# Builds docs/demo.gif and docs/screenshot.png from the real tmux.conf.
#
# It starts a throwaway tmux server, lays out four panes with sample output,
# attaches to it from a second throwaway server, and captures that screen
# (borders and all) frame by frame. Nothing touches your own tmux sessions.
#
# Needs: tmux, python3, node with Playwright, ffmpeg.
#   PLAYWRIGHT=/path/to/node_modules/playwright scripts/demo.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
IN="bt-demo-$$"; OUT="bt-outer-$$"
COLS=118; ROWS=30
export LANG=C.UTF-8 LC_ALL=C.UTF-8

cleanup() { tmux -L "$IN" kill-server 2>/dev/null || true; tmux -L "$OUT" kill-server 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

# Sample projects and what each pane prints.
mkdir -p "$WORK"/{api,web,infra,notes}
cat > "$WORK/api.txt" <<'EOF'
$ npm test

 PASS  src/auth/session.test.ts
 PASS  src/auth/password.test.ts
 PASS  src/routes/users.test.ts
 RUNS  src/routes/billing.test.ts
EOF
cat > "$WORK/web.txt" <<'EOF'
$ npm run build

  Creating an optimized production build
  Compiled successfully
  Route (app)              Size
  /                        4.1 kB
  /pricing                 2.7 kB
  /dashboard               8.9 kB
EOF
cat > "$WORK/infra.txt" <<'EOF'
$ terraform plan

  + aws_s3_bucket.backups
  ~ aws_instance.web  (instance_type)
  - aws_eip.old

Plan: 1 to add, 1 to change, 1 to destroy.
Apply these changes? [y/N]
EOF
cat > "$WORK/notes.txt" <<'EOF'
$ git log --oneline -4
a41c9e2 Add retry to webhook sender
7d03b1f Fix timezone in invoice dates
2be8c55 Cache pricing page for 5 min
f19a0d4 Bump node to 22
EOF

T() { tmux -L "$IN" "$@"; }
pane_run() { # pane, dir, file
  T send-keys -t "$1" "cd $WORK/$2 && clear && cat $WORK/$3" Enter
}

T -f "$ROOT/tmux.conf" new-session -d -s demo -x "$COLS" -y $((ROWS - 1)) "bash --norc --noprofile"
T set -g status off
T split-window -h -t demo "bash --norc --noprofile"
T split-window -v -t demo:0.0 "bash --norc --noprofile"
T split-window -v -t demo:0.2 "bash --norc --noprofile"
T set -g default-command "bash --norc --noprofile"
for p in 0 1 2 3; do T send-keys -t demo:0.$p "PS1='\$ '" Enter; done
pane_run demo:0.0 api api.txt
pane_run demo:0.1 web web.txt
pane_run demo:0.2 infra infra.txt
pane_run demo:0.3 notes notes.txt
T select-pane -t demo:0.0 -T "running the test suite"
T select-pane -t demo:0.1 -T "production build"
T select-pane -t demo:0.2 -T "plan for the new bucket"
T select-pane -t demo:0.3 -T "history"

# Second server that just shows the first one, so capture-pane sees the borders.
printf 'set -g default-terminal tmux-256color\nset -g status off\n' > "$WORK/outer.conf"
tmux -L "$OUT" -f "$WORK/outer.conf" -u new-session -d -x "$COLS" -y "$ROWS" "env TMUX= tmux -u -L $IN attach -t demo"

light() { if [ "$2" = off ]; then T set -p -u -t "demo:0.$1" @light; else T set -p -t "demo:0.$1" @light "$2"; fi; }
n=0
frame() { # seconds on screen
  sleep 1.2
  tmux -L "$OUT" capture-pane -e -p -t 0 > "$WORK/f$n.txt"
  python3 "$ROOT/scripts/ansi2html.py" "$WORK/f$n.txt" > "$WORK/f$n.html"
  echo "$1" > "$WORK/f$n.dur"
  n=$((n + 1))
}

# The story: three agents start, one finishes, one stops to ask, you answer it.
T select-pane -t demo:0.3
light 0 off; light 1 off; light 2 off;          frame 1.2
light 0 🟡; light 1 🟡; light 2 🟡;            frame 1.4
light 1 🟢;                                     frame 1.4
light 2 🔴;                                     frame 1.8
T select-pane -t demo:0.2;                      frame 1.4
light 2 🟡;                                     frame 1.2
light 0 🟢;                                     frame 2.4

# Render every frame, then stitch them.
node "$ROOT/scripts/render.js" "$WORK" "$n"
cp "$WORK/f3.png" "$ROOT/docs/screenshot.png"
: > "$WORK/list.txt"
for i in $(seq 0 $((n - 1))); do
  printf "file '%s'\nduration %s\n" "$WORK/f$i.png" "$(cat "$WORK/f$i.dur")" >> "$WORK/list.txt"
done
printf "file '%s'\n" "$WORK/f$((n - 1)).png" >> "$WORK/list.txt"
ffmpeg -loglevel error -y -f concat -safe 0 -i "$WORK/list.txt" \
  -vf "scale=1100:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=none" \
  -loop 0 "$ROOT/docs/demo.gif"
echo "docs/demo.gif and docs/screenshot.png updated"
