#!/usr/bin/env bash
# One-shot dwm setup for Kali using https://github.com/schlopshow/desktopWM
# Installs build deps, clones the repo, builds dmenu/dwm/st/dwmblocks,
# and creates a start-dwm wrapper plus a display-manager session entry.
set -euo pipefail

REPO_URL="https://github.com/schlopshow/desktopWM.git"
REPO_DIR="$HOME/desktopWM"
BUILD_ORDER=(dmenu dwm st dwmblocks)

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user (it uses sudo where needed), not as root." >&2
  exit 1
fi

echo "==> Installing dependencies"
sudo apt update
sudo apt install -y \
  build-essential git make pkg-config \
  xorg xinit x11-xserver-utils x11-utils xdotool \
  libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxrender-dev \
  libx11-xcb-dev libxcb-res0-dev libxcb1-dev \
  libfreetype6-dev libfontconfig1-dev libharfbuzz-dev libimlib2-dev \
  fonts-dejavu fonts-font-awesome fonts-noto-color-emoji \
  picom feh dunst

echo "==> Fetching your config repo"
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$REPO_DIR"
fi

echo "==> Building and installing"
FAILED=()
for d in "${BUILD_ORDER[@]}"; do
  if [ -d "$REPO_DIR/$d" ] && [ -f "$REPO_DIR/$d/Makefile" ]; then
    echo "--- $d"
    if ! ( cd "$REPO_DIR/$d" && make clean >/dev/null 2>&1 || true; \
           cd "$REPO_DIR/$d" && make -j"$(nproc)" && sudo make install ); then
      FAILED+=("$d")
    fi
  else
    echo "--- $d: no Makefile found, skipping"
  fi
done

echo "==> Creating start-dwm wrapper"
sudo tee /usr/local/bin/start-dwm >/dev/null <<'EOF'
#!/bin/sh
# Optional: wallpaper, compositor, notifications
[ -f "$HOME/.fehbg" ] && sh "$HOME/.fehbg" &
command -v picom >/dev/null 2>&1 && picom -b 2>/dev/null
command -v dunst >/dev/null 2>&1 && (dunst &) 2>/dev/null
# Status bar
command -v dwmblocks >/dev/null 2>&1 && dwmblocks &
exec dwm
EOF
sudo chmod +x /usr/local/bin/start-dwm

echo "==> Registering display-manager session"
sudo tee /usr/share/xsessions/dwm-custom.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=dwm (custom)
Comment=dwm from schlopshow/desktopWM
Exec=/usr/local/bin/start-dwm
Type=Application
EOF

echo "==> Setting up startx"
[ -f "$HOME/.xinitrc" ] && cp -n "$HOME/.xinitrc" "$HOME/.xinitrc.bak"
echo "exec /usr/local/bin/start-dwm" > "$HOME/.xinitrc"

echo
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "Done, but these failed to build: ${FAILED[*]}"
  echo "Scroll up for the compiler error (usually a missing -dev package)."
else
  echo "Done."
fi
echo "Log out and pick 'dwm (custom)' at the login screen, or run: startx"
