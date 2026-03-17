#!/usr/bin/env bash
set -e

# EdgifyOS bootstrap for Ubuntu 22.04 (jammy)
# Turns an existing Ubuntu install into an Edge-centric kiosk-like system.
#
# Usage (once hosted on GitHub, etc.):
#   curl -fsSL https://raw.githubusercontent.com/inartaly/<repo>/main/edgify-bootstrap.sh | sudo bash

EDGIFY_USER="edgify"
EDGE_CHANNEL="stable"   # stable / beta / dev
UBUNTU_CODENAME="jammy"
HOME_URL="https://www.bing.com"  # change to your portal / PWA hub

echo "[EdgifyOS] Starting bootstrap for Ubuntu 22.04 (${UBUNTU_CODENAME})..."

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (sudo)." >&2
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  echo "This script is designed for Ubuntu/Debian (apt-based)." >&2
  exit 1
fi

echo "[EdgifyOS] Updating system and installing base packages..."
apt update
DEBIAN_FRONTEND=noninteractive apt upgrade -y

DEBIAN_FRONTEND=noninteractive apt install -y \
  xorg lightdm openbox tint2 \
  software-properties-common apt-transport-https curl ca-certificates \
  fonts-dejavu-core

# Install Microsoft Edge from official repo
if ! command -v microsoft-edge-${EDGE_CHANNEL} >/dev/null 2>&1; then
  echo "[EdgifyOS] Installing Microsoft Edge (${EDGE_CHANNEL})..."
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | tee /usr/share/keyrings/microsoft-edge.gpg >/dev/null

  cat >/etc/apt/sources.list.d/microsoft-edge.list <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge ${UBUNTU_CODENAME} main
EOF

  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y microsoft-edge-${EDGE_CHANNEL}
fi

# Create dedicated kiosk user
if ! id "${EDGIFY_USER}" >/dev/null 2>&1; then
  echo "[EdgifyOS] Creating user '${EDGIFY_USER}'..."
  adduser --disabled-password --gecos "" "${EDGIFY_USER}"
fi

# Configure LightDM for autologin into Openbox session
echo "[EdgifyOS] Configuring LightDM autologin..."
mkdir -p /etc/lightdm

cat >/etc/lightdm/lightdm.conf <<EOF
[Seat:*]
autologin-user=${EDGIFY_USER}
autologin-user-timeout=0
user-session=openbox
greeter-session=lightdm-gtk-greeter
EOF

# Ensure Openbox session entry
echo "[EdgifyOS] Ensuring Openbox session..."
mkdir -p /usr/share/xsessions
cat >/usr/share/xsessions/openbox.desktop <<'EOF'
[Desktop Entry]
Name=Openbox
Comment=EdgifyOS Openbox Session
Exec=openbox-session
TryExec=openbox-session
Type=Application
EOF

# Configure Openbox autostart for the edgify user
echo "[EdgifyOS] Configuring Openbox autostart..."
EDGIFY_HOME=$(eval echo "~${EDGIFY_USER}")
mkdir -p "${EDGIFY_HOME}/.config/openbox"
chown -R "${EDGIFY_USER}:${EDGIFY_USER}" "${EDGIFY_HOME}/.config"

cat >"${EDGIFY_HOME}/.config/openbox/autostart" <<EOF
# EdgifyOS Openbox autostart

# Start tint2 panel
tint2 &

# Small delay to let X settle
sleep 2

# Launch Microsoft Edge in full-screen / app mode
microsoft-edge-${EDGE_CHANNEL} --start-fullscreen --disable-features=TranslateUI --no-first-run "${HOME_URL}" &
EOF

chown "${EDGIFY_USER}:${EDGIFY_USER}" "${EDGIFY_HOME}/.config/openbox/autostart"
chmod +x "${EDGIFY_HOME}/.config/openbox/autostart"

# Configure tint2 panel
echo "[EdgifyOS] Configuring tint2 panel..."
mkdir -p "${EDGIFY_HOME}/.config/tint2"
chown -R "${EDGIFY_USER}:${EDGIFY_USER}" "${EDGIFY_HOME}/.config/tint2"

cat >"${EDGIFY_HOME}/.config/tint2/tint2rc" <<'EOF'
# Minimal bottom panel for EdgifyOS

panel_items = LTS
panel_position = bottom center horizontal
panel_size = 100% 32
panel_margin = 0 0
panel_padding = 4 4 4
font_shadow = 0
panel_background_id = 0

# Background
rounded = 0
border_width = 0
background_color = #202020 100
border_color = #000000 0

# Launcher
launcher_padding = 4 4 4
launcher_background_id = 0
launcher_icon_size = 24
launcher_item_app = microsoft-edge-stable.desktop
# Add more launcher_item_app lines for PWAs once installed

# Taskbar
taskbar_mode = single_desktop
taskbar_padding = 4 4 4
taskbar_background_id = 0

# System tray
systray_padding = 4 4 4
systray_background_id = 0
EOF

chown "${EDGIFY_USER}:${EDGIFY_USER}" "${EDGIFY_HOME}/.config/tint2/tint2rc"

echo "[EdgifyOS] Bootstrap complete."
echo "Reboot to enter EdgifyOS (Edge-centric kiosk session as user '${EDGIFY_USER}')."
