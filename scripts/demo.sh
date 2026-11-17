#!/usr/bin/env bash
# Builds docs/demo.gif and docs/screenshot.png from the real tmux.conf.
#
# It starts a throwaway tmux server with three Claude Code panes and a plain
# shell, attaches to it from a second throwaway server, and captures that
# screen (borders and all) frame by frame. Nothing touches your own tmux.
#
# Needs: tmux, jq, python3, node with Playwright, ffmpeg.
#   PLAYWRIGHT=/path/to/node_modules/playwright scripts/demo.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
IN="bt-demo-$$"; OUT="bt-outer-$$"
COLS=124; ROWS=34
export LANG=C.UTF-8 LC_ALL=C.UTF-8

cleanup() { tmux -L "$IN" kill-server 2>/dev/null || true; tmux -L "$OUT" kill-server 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

T() { tmux -L "$IN" "$@"; }
P=(api web infra tests)   # pane 0 top-left, 1 bottom-left, 2 top-right, 3 bottom-right

T -f "$ROOT/tmux.conf" new-session -d -s demo -x "$COLS" -y "$ROWS" "bash --norc --noprofile"
T set -g status off
T split-window -h -t demo "bash --norc --noprofile"
T split-window -v -t demo:0.0 "bash --norc --noprofile"
T split-window -v -t demo:0.2 "bash --norc --noprofile"
mkdir -p "$WORK"/{api,web,infra,tests} "$WORK/s"
for p in 0 1 2 3; do
  T send-keys -t demo:0.$p "PS1='' && cd $WORK/${P[$p]} && clear" Enter
done
T select-pane -t demo:0.0 -T "Login fixes"
T select-pane -t demo:0.1 -T "Fix pricing build"
T select-pane -t demo:0.2 -T "Backups bucket"
T select-pane -t demo:0.3 -T "Test watcher"
# Pane ids, so panes can still be reached after one of them is hidden.
ID=(); W=(); H=()
for p in 0 1 2 3; do
  read -r ID[$p] W[$p] H[$p] < <(T display -p -t "demo:0.$p" '#{pane_id} #{pane_width} #{pane_height}')
done

# The screens are scripted text (four real agents would make the demo slow and
# never the same twice), but every light change goes through hooks/tmux-light.sh
# exactly like the Claude Code hooks call it, with the JSON it gets on stdin.
#
# {o} orange, {g} green, {r} red, {y} yellow, {d} grey, {b} bold, {x} reset.
colour() {
  sed -e $'s/{o}/\e[38;5;209m/g' -e $'s/{g}/\e[38;5;77m/g' -e $'s/{r}/\e[38;5;203m/g' \
      -e $'s/{y}/\e[38;5;220m/g' -e $'s/{d}/\e[38;5;244m/g' -e $'s/{b}/\e[1m/g' -e $'s/{x}/\e[0m/g'
}
rep() { local s=""; for ((i = 0; i < $1; i++)); do s+="$2"; done; printf '%s' "$s"; }
# cc PANE NAME [typed text] < conversation
# A Claude Code screen: the conversation on top, the input box at the bottom.
cc() {
  local p=$1 name=$2 typed=${3:-} w=$((W[$1] - 2)) body lines
  body="$(cat)"
  lines=$(printf '%s\n' "$body" | wc -l)
  {
    printf '%s\n' "$body"
    for ((i = lines; i < H[p] - 4; i++)); do echo; done
    echo "{d}╭$(rep $((w - 2)) ─)╮{x}"
    printf '{d}│{x} > %s%*s{d}│{x}\n' "$typed" $((w - 5 - ${#typed})) ""
    echo "{d}╰$(rep $((w - 2)) ─)╯{x}"
    printf '{d}  ? for shortcuts{x}'
  } | colour > "$WORK/s/$name"
}
shell() { colour > "$WORK/s/$2"; }   # shell PANE NAME < text

# --- api: you ask for fixes and hide the pane
cc 0 api0 <<'EOF'
{d}  ~/api · main{x}
EOF
k=0
for t in "fix login.ts TODOs" "fix login.ts TODOs + run tests." "fix login.ts TODOs + run tests. no need to watch"; do
  k=$((k + 1)); cc 0 "api-t$k" "$t" <<'EOF'
{d}  ~/api · main{x}
EOF
done
cc 0 api1 <<'EOF'
{d}>{x} fix login.ts TODOs + run tests. no need to watch

{b}●{x} On it. I'll fix the TODOs and run the tests.
  Look away, the light goes green when I'm done.

{o}✻ Working…{x}
EOF
cc 0 api2 <<'EOF'
{d}>{x} fix login.ts TODOs + run tests. no need to watch

{b}●{x} Update(src/routes/login.ts)
{d}  ⎿  Fixed 3 TODOs: input check, lockout, error text{x}
{b}●{x} Bash(npm test -- login)
{d}  ⎿  {g}14 passed{x}

{b}●{x} Done. The 3 TODOs are fixed and all 14 tests pass.
EOF

# --- web: another Claude Code session, finishes on its own
cc 1 web1 <<'EOF'
{d}>{x} the build breaks on /pricing, fix it

{b}●{x} Bash(npm run build)
{d}  ⎿  {r}Type error{d} in app/pricing/page.tsx:41{x}

{o}✻ Thinking…{x}
EOF
cc 1 web2 <<'EOF'
{d}>{x} the build breaks on /pricing, fix it

{b}●{x} Update(app/pricing/page.tsx)
{d}  ⎿  Changed 1 line{x}
{b}●{x} Bash(npm run build)
{d}  ⎿  {g}Compiled successfully{x}

{b}●{x} Fixed. price was a string in one place.
EOF

# --- infra: works, asks for permission, you answer 1
cc 2 infra1 <<'EOF'
{d}>{x} create the backups bucket

{b}●{x} Update(main.tf)
{d}  ⎿  Added 9 lines{x}
{b}●{x} Bash(terraform plan)
{d}  ⎿  Plan: 1 to add, 0 to change, 0 to destroy{x}

{o}✻ Working…{x}
EOF
cc 2 infra2 <<'EOF'
{b}●{x} Bash(terraform plan)
{d}  ⎿  Plan: 1 to add, 0 to change, 0 to destroy{x}

{o}╭────────────────────────────────────────────────╮{x}
{o}│{x} {b}Bash command{x}                                   {o}│{x}
{o}│{x}   terraform apply -auto-approve                {o}│{x}
{o}│{x} Do you want to proceed?                        {o}│{x}
{o}│{x} {o}❯{x} 1. Yes                                       {o}│{x}
{o}│{x}   2. No, and tell Claude what to do instead    {o}│{x}
{o}╰────────────────────────────────────────────────╯{x}
EOF
cc 2 infra3 <<'EOF'
{b}●{x} Bash(terraform plan)
{d}  ⎿  Plan: 1 to add, 0 to change, 0 to destroy{x}
{b}●{x} Bash(terraform apply -auto-approve)
{d}  ⎿  Applying…{x}

{o}✻ Working…{x}
EOF
cc 2 infra4 <<'EOF'
{b}●{x} Bash(terraform plan)
{d}  ⎿  Plan: 1 to add, 0 to change, 0 to destroy{x}
{b}●{x} Bash(terraform apply -auto-approve)
{d}  ⎿  {g}Apply complete!{d} Resources: 1 added{x}

{b}●{x} Bucket backups-prod is up, versioning on.
EOF

# --- tests: a plain shell, no agent, no light
shell 3 tests1 <<'EOF'
$ npm test -- --watch

 {g}PASS{x}  src/routes/signup.test.ts
 {g}PASS{x}  src/routes/pricing.test.ts
 {g}PASS{x}  src/lib/money.test.ts

Tests:  {g}41 passed{x}, 41 total
{d}Watching for changes…{x}
EOF
shell 3 tests2 <<'EOF'
$ npm test -- --watch

 {g}PASS{x}  src/routes/signup.test.ts
 {g}PASS{x}  src/routes/pricing.test.ts
 {g}PASS{x}  src/routes/login.test.ts
 {g}PASS{x}  src/lib/money.test.ts

Tests:  {g}55 passed{x}, 55 total
{d}Watching for changes…{x}
EOF

show() { T send-keys -t "${ID[$1]}" "clear && cat $WORK/s/$2" Enter; }

# Second server that just shows the first one, so capture-pane sees the borders.
printf 'set -g default-terminal tmux-256color\nset -g status off\n' > "$WORK/outer.conf"
tmux -L "$OUT" -f "$WORK/outer.conf" -u new-session -d -x "$COLS" -y "$ROWS" "env TMUX= tmux -u -L $IN attach -t demo"

# Call the hook the way Claude Code does: inside the pane's environment.
SOCK="$(T display -p '#{socket_path}')"
hook() { # pane, state, [last message for Stop]
  jq -n --arg m "${3:-}" '{hook_event_name:"Stop", last_assistant_message:$m}' |
    TMUX="$SOCK,0,0" TMUX_PANE="${ID[$1]}" "$ROOT/hooks/tmux-light.sh" "$2"
}
hide() { TMUX="$SOCK,0,0" "$ROOT/hooks/tmux-hide.sh" "$(T display -p -t demo '#{pane_id}')"; }
n=0
frame() { # seconds on screen, [key shown on screen]
  sleep "${WAIT:-1.2}"
  tmux -L "$OUT" capture-pane -e -N -p -t 0 > "$WORK/f$n.txt"
  python3 "$ROOT/scripts/ansi2html.py" "$WORK/f$n.txt" > "$WORK/f$n.html"
  echo "$1" > "$WORK/f$n.dur"
  echo "${2:-}" > "$WORK/f$n.key"
  # the pointer rests near the bottom right of the active pane, clear of the text
  T display -p -t demo '#{e|-:#{e|+:#{pane_left},#{pane_width}},12} #{e|-:#{e|+:#{pane_top},#{pane_height}},7}' > "$WORK/f$n.cur"
  n=$((n + 1))
}

# The story. You ask the api agent for fixes and hide its pane. Meanwhile the
# web agent finishes and the infra agent asks for permission. You click it,
# press 1, it finishes. The hidden api pane turns green and you bring it back.
# The shell pane has no agent, so no light. Focus mode fades every pane you
# are not in.
T select-pane -t "${ID[0]}"
show 0 api0; show 1 web1; hook 1 busy; show 2 infra1; hook 2 busy; show 3 tests1
                                                                  frame 1.4
for t in api-t1 api-t2 api-t3; do show 0 $t; WAIT=0.5 frame 0.35; done
                                                       echo 0.9 > "$WORK/f$((n - 1)).dur"
show 0 api1; hook 0 busy;                                         frame 1.4 "⏎"
hide;                                     WAIT=2.5                frame 1.4 "Ctrl+b  H"
show 1 web2; hook 1 done "Fixed. price was a string in one place."
show 2 infra2; hook 2 ask;                                        frame 1.6
T select-pane -t "${ID[2]}";                                      frame 1.4
show 2 infra3; hook 2 busy;                                       frame 1.2 "1"
show 2 infra4; hook 2 done "Bucket backups-prod is up."
show 0 api2; hook 0 done "The 3 TODOs are fixed."; show 3 tests2
                                          WAIT=2.5                frame 1.8
T select-pane -t "$(T display -p -t demo:0.0 '#{pane_id}')";      frame 0.8
hide; show 0 api2   # redraw at the pane's size again
                                                                  frame 3.2 "Ctrl+b  H"
SHOT=7   # frame used for docs/screenshot.png: api hidden, web green, infra asking

# Render every frame (mouse pointer, key presses), then stitch them.
node "$ROOT/scripts/render.js" "$WORK" "$n"
cp "$WORK/f$SHOT.png" "$ROOT/docs/screenshot.png"
ffmpeg -loglevel error -y -f concat -safe 0 -i "$WORK/list.txt" \
  -vf "scale=1100:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=none" \
  -loop 0 "$ROOT/docs/demo.gif"
echo "docs/demo.gif and docs/screenshot.png updated"
