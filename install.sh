#!/usr/bin/env bash
# rgb-display-widget installer.
#
#   ./install.sh              link the backend scripts into ~/.local/bin and check dependencies
#   ./install.sh reed-tpse    fetch upstream reed-tpse, apply patches/, build and install it
#   ./install.sh serpantinum  [--enable] [SHELL_DIR]   install the Serpantinum bar button + popout
#   ./install.sh help
#
# Environment overrides: PREFIX (default ~/.local), BIN_DIR (default $PREFIX/bin),
#                        SYSTEMD_USER_DIR (default ~/.config/systemd/user)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="${BIN_DIR:-$PREFIX/bin}"
SYSTEMD_USER_DIR="${SYSTEMD_USER_DIR:-$HOME/.config/systemd/user}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rgb-display-widget"

REED_REPO="https://github.com/fadli0029/reed-tpse.git"
REED_COMMIT="69c73974988c30dd0d9b9464dc9ebd051b8875c5"   # the commit patches/ apply to

say()  { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31mError: %s\033[0m\n' "$*" >&2; exit 1; }

install_hint() {
  local pkgs_arch="$1" pkgs_deb="$2" pkgs_fed="$3"
  if   command -v pacman >/dev/null; then echo "  sudo pacman -S --needed $pkgs_arch"
  elif command -v apt    >/dev/null; then echo "  sudo apt install $pkgs_deb"
  elif command -v dnf    >/dev/null; then echo "  sudo dnf install $pkgs_fed"
  fi
}

cmd_scripts() {
  say "Linking backend scripts into $BIN_DIR"
  mkdir -p "$BIN_DIR"
  for s in tryx-ctl rgb-ctl; do ln -sfn "$here/backend/$s" "$BIN_DIR/$s"; echo "  $BIN_DIR/$s"; done

  say "Checking dependencies"
  local missing=0
  for c in openrgb adb ffmpeg ffprobe python3 reed-tpse; do
    if command -v "$c" >/dev/null || [[ -x "$BIN_DIR/$c" ]]; then printf '  ok       %s\n' "$c"
    else printf '  MISSING  %s\n' "$c"; missing=1; fi
  done
  if (( missing )); then
    echo
    warn "Some tools are missing. Typical packages:"
    install_hint "openrgb android-tools ffmpeg python" "openrgb adb ffmpeg python3" "openrgb android-tools ffmpeg python3"
    command -v reed-tpse >/dev/null || [[ -x "$BIN_DIR/reed-tpse" ]] || echo "  reed-tpse: run  ./install.sh reed-tpse"
  fi

  # Serial access for the TRYX display
  local grp=uucp; getent group dialout >/dev/null && ! getent group uucp >/dev/null && grp=dialout
  if ! id -nG | tr ' ' '\n' | grep -qx "$grp"; then
    echo
    warn "You are not in the '$grp' group, which owns /dev/ttyACM* (the TRYX serial port)."
    echo "  sudo usermod -aG $grp \$USER   # then log out and back in"
  fi
  echo
  say "Done. Try:  rgb-ctl state    and    tryx-ctl state"
}

cmd_reed() {
  command -v git   >/dev/null || die "git is required"
  command -v cmake >/dev/null || die "cmake is required"
  command -v g++   >/dev/null || command -v c++ >/dev/null || die "a C++17 compiler is required"
  local src="$CACHE/reed-tpse-src"
  mkdir -p "$CACHE"
  if [[ ! -d "$src/.git" ]]; then say "Cloning reed-tpse"; git clone -q "$REED_REPO" "$src"; fi
  say "Checking out the pinned upstream commit and applying patches"
  git -C "$src" fetch -q origin "$REED_COMMIT" 2>/dev/null || git -C "$src" fetch -q origin
  git -C "$src" checkout -q -f "$REED_COMMIT"
  git -C "$src" clean -qfdx
  for p in "$here"/patches/*.patch; do
    git -C "$src" apply "$p" && echo "  applied $(basename "$p")"
  done
  say "Building"
  cmake -S "$src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" >/dev/null
  cmake --build "$src/build" -j"$(nproc)" >/dev/null
  cmake --install "$src/build" >/dev/null
  echo "  installed $PREFIX/bin/reed-tpse"
  # systemd user unit (keeps the display alive). Point it at the chosen prefix.
  mkdir -p "$SYSTEMD_USER_DIR"
  sed "s#^ExecStart=.*#ExecStart=$PREFIX/bin/reed-tpse daemon start --foreground#" \
      "$src/systemd/reed-tpse.service" > "$SYSTEMD_USER_DIR/reed-tpse.service"
  echo "  installed $SYSTEMD_USER_DIR/reed-tpse.service"
  command -v systemctl >/dev/null && systemctl --user daemon-reload 2>/dev/null || true
  say "Done. Check the display with:  reed-tpse info"
}

case "${1:-scripts}" in
  scripts|"")   cmd_scripts ;;
  reed-tpse)    cmd_reed ;;
  serpantinum)  shift; exec "$here/adapters/serpantinum/install.sh" "$@" ;;
  help|-h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown command '$1' (try: ./install.sh help)" ;;
esac
