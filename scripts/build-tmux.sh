#!/usr/bin/env bash
# Builds tmux 3.4 with the split-border patch (patches/tmux-3.4-split-border.patch).
# With it, a border shared by two panes shows both colours: one half each,
# the most recently selected pane on top (vertical border) or right (horizontal).
#
#   scripts/build-tmux.sh             build only, binary goes to ./build/tmux
#   scripts/build-tmux.sh --install   also copy it to /usr/local/bin/tmux
#
# Builds inside a throwaway Docker container when Docker is available,
# otherwise on this machine (needs gcc, make, bison, pkg-config,
# libevent-dev, libncurses-dev).
# Running tmux servers keep the old code: the split shows up in new servers.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER=3.4
SHA=551ab8dea0bf505c0ad6b7bb35ef567cdde0ccb84357df142c254f35a23e19aa
URL="https://github.com/tmux/tmux/releases/download/$VER/tmux-$VER.tar.gz"
OUT="$ROOT/build"
mkdir -p "$OUT"

build() { # runs in the source parent dir: $1 = dir with the patch
  curl -fsSL "$URL" -o tmux.tar.gz
  echo "$SHA  tmux.tar.gz" | sha256sum -c - >/dev/null
  tar xzf tmux.tar.gz
  cd "tmux-$VER"
  patch -p1 < "$1/tmux-$VER-split-border.patch"
  ./configure --prefix=/usr/local >/dev/null
  make -j"$(nproc)" >/dev/null
}

if command -v docker >/dev/null && [ "${NO_DOCKER:-}" != 1 ]; then
  . /etc/os-release
  docker run --rm \
    -v "$ROOT/patches:/patches:ro" -v "$OUT:/out" \
    -e VER="$VER" -e SHA="$SHA" -e URL="$URL" -e HOSTUID="$(id -u)" \
    "${ID:-ubuntu}:${VERSION_ID:-24.04}" bash -euo pipefail -c "
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq >/dev/null
      apt-get install -y -qq curl ca-certificates gcc make bison pkg-config patch \
        libevent-dev libncurses-dev >/dev/null
      cd /tmp
      $(declare -f build)
      build /patches
      install -m 755 tmux /out/tmux
      chown \$HOSTUID /out/tmux"
else
  WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
  ( cd "$WORK" && build "$ROOT/patches" && install -m 755 tmux "$OUT/tmux" )
fi
"$OUT/tmux" -V
echo "built: $OUT/tmux"

if [ "${1:-}" = "--install" ]; then
  install -m 755 "$OUT/tmux" /usr/local/bin/tmux
  echo "installed: /usr/local/bin/tmux (open a new tmux server to see the split)"
fi
