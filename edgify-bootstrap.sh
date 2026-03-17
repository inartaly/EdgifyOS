#!/usr/bin/env bash
set -e

# ============================================================
#  EdgifyOS Interactive Installer / Uninstaller
#  Ubuntu 22.04 → Edge‑centric kiosk environment
#
#  Install or uninstall using:
#     curl -fsSL https://raw.githubusercontent.com/inartaly/EdgifyOS/main/edgify-bootstrap.sh | sudo bash
#
#  Repository:
#     https://github.com/inartaly/EdgifyOS
# ============================================================

EDGIFY_USER="edgify"
EDGE_CHANNEL="stable"
UBUNTU_CODENAME="jammy"
HOME_URL="https://www.bing.com"
BACKUP_DIR="/var/lib/edgifyos-backup"

# ------------------------------------------------------------
# Helper: ensure root
# ------------------------------------------------------------
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Please run as root (sudo)."
        exit 1
    fi
}

# ------------------------------------------------------------
# INSTALL MODE
# ------------------------------------------------------------
install_edgifyos() {
    echo "[EdgifyOS] Starting installation..."

    mkdir -p "$BACKUP_DIR"

    # Backup LightDM config if exists
    if [ -f /etc/lightdm/lightdm.conf ]; then
        cp /etc/lightdm/lightdm.conf "$BACKUP_DIR/lightdm.conf.bak"
    fi

    # Backup Openbox session if exists
    if [ -f /usr/share/xsessions/openbox.desktop ]; then
        cp /usr/share/xsessions/openbox.desktop "$BACKUP_DIR/openbox.desktop.bak"
    fi

    echo "[EdgifyOS] Updating system..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt upgrade -y

    echo "[EdgifyOS] Installing required packages..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        xorg lightdm openbox tint2 \
        software-properties-common apt-transport-https curl ca-certificates \
        fonts-dejavu-core

    # Install Microsoft Edge
    if ! command -v microsoft-edge-${EDGE_CHANNEL} >/dev/null 2>&1; then
        echo "[EdgifyOS] Installing Microsoft Edge..."
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
            | gpg --dearmor \
            | tee /usr/share/keyrings/microsoft-edge.gpg >/dev/null

        cat >/etc/apt/sources.list.d/microsoft-edge.list <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge ${UBUNTU_CODENAME} main
EOF

        apt update
        DEBIAN_FRONTEND=noninteractive apt install -y microsoft-edge-${EDGE_CHANNEL}
    fi

    # Create kiosk user
    if ! id "$EDGIFY_USER" >/dev/null 2>&1; then
        echo "[EdgifyOS] Creating user '$EDGIFY_USER'..."
        adduser --disabled-password --gecos "" "$EDGIFY_USER"
    fi

    # Configure LightDM autologin
    echo "[EdgifyOS] Configuring LightDM autologin..."
    mkdir -p /etc/lightdm
    cat >/etc/lightdm/lightdm.conf <<EOF
[Seat:*]
autologin-user=${EDGIFY_USER}
autologin-user-timeout=0
user-session=openbox
greeter-session=lightdm-gtk-greeter
EOF

    # Create Openbox session entry
    echo "[EdgifyOS] Creating Openbox session..."
    mkdir -p /usr/share/xsessions
    cat >/usr/share/xsessions/openbox.desktop <<'EOF'
[Desktop Entry]
Name=Openbox
Comment=EdgifyOS Openbox Session
Exec=openbox-session
TryExec=openbox-session
Type=Application
EOF

    # Configure Openbox autostart
    echo "[EdgifyOS] Configuring Openbox autostart..."
    EDGIFY_HOME=$(eval echo "~${EDGIFY_USER}")
    mkdir -p "${EDGIFY_HOME}/.config/openbox"

    cat >"${EDGIFY_HOME}/.config/openbox/autostart" <<EOF
tint2 &
sleep 2
microsoft-edge-${EDGE_CHANNEL} --start-fullscreen --disable-features=TranslateUI --no-first-run "${HOME_URL}" &
EOF

    chown -R "${EDGIFY_USER}:${EDGIFY_USER}" "${EDGIFY_HOME}/.config"

    # Configure Tint2
    echo "[EdgifyOS] Configuring Tint2 panel..."
    mkdir -p "${EDGIFY_HOME}/.config/tint2"
    cat >"${EDGIFY_HOME}/.config/tint2/tint2rc" <<'EOF'
panel_items = LTS
panel_position = bottom center horizontal
panel_size = 100% 32
panel_background_id = 0
launcher_item_app = microsoft-edge-stable.desktop
EOF

    chown -R "${EDGIFY_USER}:${EDGIFY_USER}" "${EDGIFY_HOME}/.config/tint2"

    echo ""
    echo "===================================================="
    echo " EdgifyOS installation complete!"
    echo " Reboot to enter the Edge‑centric kiosk environment."
    echo "===================================================="
}

# ------------------------------------------------------------
# UNINSTALL MODE
# ------------------------------------------------------------
uninstall_edgifyos() {
    echo "[EdgifyOS] Starting uninstall..."

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "No EdgifyOS backup found. Cannot revert."
        exit 1
    fi

    # Restore LightDM config
    if [ -f "$BACKUP_DIR/lightdm.conf.bak" ]; then
        cp "$BACKUP_DIR/lightdm.conf.bak" /etc/lightdm/lightdm.conf
    else
        rm -f /etc/lightdm/lightdm.conf
    fi

    # Restore Openbox session
    if [ -f "$BACKUP_DIR/openbox.desktop.bak" ]; then
        cp "$BACKUP_DIR/openbox.desktop.bak" /usr/share/xsessions/openbox.desktop
    else
        rm -f /usr/share/xsessions/openbox.desktop
    fi

    # Remove user configs
    EDGIFY_HOME=$(eval echo "~${EDGIFY_USER}")
    rm -rf "${EDGIFY_HOME}/.config/openbox" || true
    rm -rf "${EDGIFY_HOME}/.config/tint2" || true

    # Ask whether to delete the user
    read -rp "Delete the 'edgify' user and its home directory? [y/N]: " DELUSER
    if [[ "$DELUSER" =~ ^[Yy]$ ]]; then
        deluser --remove-home "$EDGIFY_USER" || true
    fi

    echo ""
    echo "===================================================="
    echo " EdgifyOS has been removed."
    echo " Your system is restored to normal Ubuntu behavior."
    echo "===================================================="
}

# ------------------------------------------------------------
# MAIN MENU
# ------------------------------------------------------------
main_menu() {
    echo ""
    echo "What would you like to do?"
    echo ""
    echo "  1) Install EdgifyOS"
    echo "  2) Uninstall EdgifyOS (Revert to Ubuntu)"
    echo "  3) Cancel"
    echo ""

    read -rp "Enter choice [1-3]: " CHOICE

    case "$CHOICE" in
        1) install_edgifyos ;;
        2) uninstall_edgifyos ;;
        3) echo "Cancelled."; exit 0 ;;
        *) echo "Invalid choice."; exit 1 ;;
    esac
}

# ------------------------------------------------------------
# RUN
# ------------------------------------------------------------
require_root
main_menu
