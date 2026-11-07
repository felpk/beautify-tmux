#!/usr/bin/env bash
# Builds docs/demo.gif and docs/screenshot.png from the real tmux.conf.
#
# It starts a throwaway tmux server with four Claude Code panes,
# attaches to it from a second throwaway server, and captures that screen
# (borders and all) frame by frame. Nothing touches your own tmux sessions.
#
# Needs: tmux, jq, python3, node with Playwright, ffmpeg.
#   PLAYWRIGHT=/path/to/node_modules/playwright scripts/demo.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
IN="bt-demo-$$"; OUT="bt-outer-$$"
COLS=118; ROWS=30
export LANG=C.UTF-8 LC_ALL=C.UTF-8

cleanup() { tmux -L "$IN" kill-server 2>/dev/null || true; tmux -L "$OUT" kill-server 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

# Each pane is a Claude Code session. The screens are scripted text files
# (running four real agents would make the demo slow and never the same twice),
# but every light change goes through hooks/tmux-light.sh exactly like the
# Claude Code hooks call it, including the JSON it gets on stdin.
mkdir -p "$WORK"/{api,web,infra,docs} "$WORK/s"
# screen NAME, then the text on stdin. {o} orange, {g} green, {r} red,
# {d} grey, {b} bold, {x} reset.
screen() {
  sed -e $'s/{o}/\e[38;5;209m/g' -e $'s/{g}/\e[38;5;77m/g' -e $'s/{r}/\e[38;5;203m/g' \
      -e $'s/{d}/\e[38;5;244m/g' -e $'s/{b}/\e[1m/g' -e $'s/{x}/\e[0m/g' > "$WORK/s/$1"
}

screen api1 <<'EOF'
{d}>{x} add rate limiting to POST /login

{b}●{x} Read(src/routes/login.ts)
{d}  ⎿  Read 84 lines{x}

{o}✻ Thinking…{x}
EOF
screen api2 <<'EOF'
{d}>{x} add rate limiting to POST /login

{b}●{x} Read(src/routes/login.ts)
{d}  ⎿  Read 84 lines{x}
{b}●{x} Update(src/routes/login.ts)
{d}  ⎿  Added 12 lines{x}
{b}●{x} Bash(npm test -- login)
{d}  ⎿  Running…{x}

{o}✻ Running tests…{x}
EOF
screen api3 <<'EOF'
{d}>{x} add rate limiting to POST /login

{b}●{x} Update(src/routes/login.ts)
{d}  ⎿  Added 12 lines{x}
{b}●{x} Bash(npm test -- login)
{d}  ⎿  14 passed{x}

{b}●{x} Login now allows 5 tries per minute per IP.
  The sixth one gets a 429.
EOF
screen web1 <<'EOF'
{d}>{x} the build breaks on /pricing, fix it

{b}●{x} Bash(npm run build)
{d}  ⎿  {r}Type error{d} in app/pricing/page.tsx:41{x}

{o}✻ Thinking…{x}
EOF
screen web2 <<'EOF'
{d}>{x} the build breaks on /pricing, fix it

{b}●{x} Bash(npm run build)
{d}  ⎿  {r}Type error{d} in app/pricing/page.tsx:41{x}
{b}●{x} Update(app/pricing/page.tsx)
{d}  ⎿  Changed 1 line{x}
{b}●{x} Bash(npm run build)
{d}  ⎿  {g}Compiled successfully{x}

{b}●{x} Fixed. price was a string in one place.
EOF
screen infra1 <<'EOF'
{d}>{x} create the backups bucket

{b}●{x} Update(main.tf)
{d}  ⎿  Added 9 lines{x}
{b}●{x} Bash(terraform plan)
{d}  ⎿  Plan: 1 to add, 0 to change, 0 to destroy{x}

{o}✻ Working…{x}
EOF
screen infra2 <<'EOF'
{b}●{x} Bash(terraform plan)
{d}  ⎿  Plan: 1 to add, 0 to change, 0 to destroy{x}

{o}╭──────────────────────────────────────────────╮{x}
{o}│{x} {b}Bash command{x}                                 {o}│{x}
{o}│{x}   terraform apply -auto-approve              {o}│{x}
{o}│{x} Do you want to proceed?                      {o}│{x}
{o}│{x} {o}❯{x} 1. Yes                                     {o}│{x}
{o}│{x}   2. No, and tell Claude what to do instead  {o}│{x}
{o}╰──────────────────────────────────────────────╯{x}
EOF
screen infra3 <<'EOF'
{d}>{x} create the backups bucket

{b}●{x} Bash(terraform plan)
{d}  ⎿  Plan: 1 to add, 0 to change, 0 to destroy{x}
{b}●{x} Bash(terraform apply -auto-approve)
{d}  ⎿  {g}Apply complete!{d} Resources: 1 added{x}

{b}●{x} Bucket backups-prod is up, versioning on.
EOF
screen docs1 <<'EOF'
{d}>{x} put the new env vars in the README

{b}●{x} Read(.env.example)
{d}  ⎿  Read 22 lines{x}

{o}✻ Thinking…{x}
EOF
screen docs2 <<'EOF'
{d}>{x} put the new env vars in the README

{b}●{x} Read(.env.example)
{d}  ⎿  Read 22 lines{x}
{b}●{x} Update(README.md)
{d}  ⎿  Added 6 lines{x}

{b}●{x} Added SMTP_HOST and SMTP_PORT.
  There's an old REDIS_URL in there too.
  Should I take it out?
EOF
screen docs3 <<'EOF'
{b}●{x} Added SMTP_HOST and SMTP_PORT.
  There's an old REDIS_URL in there too.
  Should I take it out?

{d}>{x} yes

{o}✻ Working…{x}
EOF
screen docs4 <<'EOF'
{b}●{x} Added SMTP_HOST and SMTP_PORT.
  There's an old REDIS_URL in there too.
  Should I take it out?

{d}>{x} yes

{b}●{x} Update(README.md)
{d}  ⎿  Removed 1 line{x}
{b}●{x} Done, REDIS_URL is gone.
EOF

T() { tmux -L "$IN" "$@"; }
P=(api web infra docs)   # pane 0..3
show() { T send-keys -t "demo:0.$1" "clear && cat $WORK/s/$2" Enter; }

T -f "$ROOT/tmux.conf" new-session -d -s demo -x "$COLS" -y $((ROWS - 1)) "bash --norc --noprofile"
T set -g status off
T split-window -h -t demo "bash --norc --noprofile"
T split-window -v -t demo:0.0 "bash --norc --noprofile"
T split-window -v -t demo:0.2 "bash --norc --noprofile"
# split order leaves panes as 0 top-left, 1 bottom-left, 2 top-right, 3 bottom-right
for p in 0 1 2 3; do
  T send-keys -t demo:0.$p "PS1='' && cd $WORK/${P[$p]} && clear" Enter
done
T select-pane -t demo:0.0 -T "Rate limit on login"
T select-pane -t demo:0.1 -T "Fix pricing build"
T select-pane -t demo:0.2 -T "Backups bucket"
T select-pane -t demo:0.3 -T "Env vars in README"

# Second server that just shows the first one, so capture-pane sees the borders.
printf 'set -g default-terminal tmux-256color\nset -g status off\n' > "$WORK/outer.conf"
tmux -L "$OUT" -f "$WORK/outer.conf" -u new-session -d -x "$COLS" -y "$ROWS" "env TMUX= tmux -u -L $IN attach -t demo"

# Call the hook the way Claude Code does: inside the pane's environment.
SOCK="$(T display -p '#{socket_path}')"
hook() { # pane, state, [last message for Stop]
  local id; id="$(T display -p -t "demo:0.$1" '#{pane_id}')"
  jq -n --arg m "${3:-}" '{hook_event_name:"Stop", last_assistant_message:$m}' |
    TMUX="$SOCK,0,0" TMUX_PANE="$id" "$ROOT/hooks/tmux-light.sh" "$2"
}
n=0
frame() { # seconds on screen
  sleep 1.2
  tmux -L "$OUT" capture-pane -e -p -t 0 > "$WORK/f$n.txt"
  python3 "$ROOT/scripts/ansi2html.py" "$WORK/f$n.txt" > "$WORK/f$n.html"
  echo "$1" > "$WORK/f$n.dur"
  n=$((n + 1))
}

# The story: four agents start, two finish, one asks for permission,
# one ends on a question, you answer both and everything goes green.
T select-pane -t demo:0.0
for p in 0 1 2 3; do show $p "${P[$p]}1"; hook $p busy; done;     frame 1.6
show 0 api2; show 1 web2; hook 1 done "Fixed. price was a string in one place.";  frame 1.6
show 2 infra2; hook 2 ask;                                          frame 1.8
show 3 docs2; hook 3 done "Should I take it out?";                  frame 2.0
T select-pane -t demo:0.2; show 2 infra3; hook 2 done "Bucket backups-prod is up."; frame 1.6
T select-pane -t demo:0.3; show 3 docs3; hook 3 busy;               frame 1.4
show 0 api3; hook 0 done "The sixth one gets a 429."
show 3 docs4; hook 3 done "Done, REDIS_URL is gone.";               frame 3.0

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
