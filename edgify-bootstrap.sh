#!/usr/bin/env bash
set -e

# ============================================================
#  EdgifyOS Installer / Uninstaller
#  Ubuntu 22.04 → ChromeOS‑like interface using Flatpak Edge
#
#  Direct install:
#     curl -fsSL https://raw.githubusercontent.com/inartaly/EdgifyOS/main/edgify-bootstrap.sh | sudo bash -s install
#
#  Direct uninstall:
#     curl -fsSL https://raw.githubusercontent.com/inartaly/EdgifyOS/main/edgify-bootstrap.sh | sudo bash -s revert
#
#  Interactive:
#     sudo bash edgify-bootstrap.sh
# ============================================================

# Ensure curl exists on fresh Ubuntu installs
if ! command -v curl >/dev/null 2>&1; then
    echo "[EdgifyOS] curl not found — installing..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y curl
fi


EDGIFY_USER="edgify"
HOME_URL="https://www.bing.com"
BACKUP_DIR="/var/lib/edgifyos-backup"

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Please run as root (sudo)."
        exit 1
    fi
}

install_edgifyos() {
    echo "[EdgifyOS] Starting installation..."

    mkdir -p "$BACKUP_DIR"

    # Backup configs
    [ -f /etc/lightdm/lightdm.conf ] && cp /etc/lightdm/lightdm.conf "$BACKUP_DIR/lightdm.conf.bak"
    [ -f /usr/share/xsessions/openbox.desktop ] && cp /usr/share/xsessions/openbox.desktop "$BACKUP_DIR/openbox.desktop.bak"

    echo "[EdgifyOS] Updating system..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt upgrade -y

    echo "[EdgifyOS] Installing required packages..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        xorg lightdm openbox tint2 flatpak \
        software-properties-common apt-transport-https curl ca-certificates \
        fonts-dejavu-core

    echo "[EdgifyOS] Setting LightDM as the default display manager..."
    echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure lightdm

    echo "[EdgifyOS] Adding Flathub (if missing)..."
    if ! flatpak remote-list | grep -q flathub; then
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi

    echo "[EdgifyOS] Installing Microsoft Edge (Flatpak)..."
    flatpak install -y flathub com.microsoft.Edge

    if ! id "$EDGIFY_USER" >/dev/null 2>&1; then
    echo "[EdgifyOS] Creating user '$EDGIFY_USER'..."
    adduser --disabled-password --gecos "" "$EDGIFY_USER"

    echo ""
    echo "[EdgifyOS] Please set a password for the 'edgify' user."
    echo "This is required for sudo access inside the kiosk session."
    passwd "$EDGIFY_USER"
    fi


    echo "[EdgifyOS] Configuring LightDM autologin..."
    mkdir -p /etc/lightdm
    cat >/etc/lightdm/lightdm.conf <<EOF
[Seat:*]
autologin-user=${EDGIFY_USER}
autologin-user-timeout=0
user-session=openbox
greeter-session=lightdm-gtk-greeter
EOF

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

    echo "[EdgifyOS] Configuring Openbox autostart..."
    EDGIFY_HOME=$(eval echo "~${EDGIFY_USER}")
    mkdir -p "${EDGIFY_HOME}/.config/openbox"

    cat >"${EDGIFY_HOME}/.config/openbox/autostart" <<EOF
tint2 &
sleep 2
flatpak run com.microsoft.Edge --start-maximized --no-first-run "${HOME_URL}" &
EOF

    chown -R "${EDGIFY_USER}:${EDGIFY_USER}" "${EDGIFY_HOME}/.config"

    echo "[EdgifyOS] Configuring Tint2 panel..."
    mkdir -p "${EDGIFY_HOME}/.config/tint2"
    cat >"${EDGIFY_HOME}/.config/tint2/tint2rc" <<'EOF'
panel_items = LTS
panel_position = bottom center horizontal
panel_size = 100% 32
panel_background_id = 0
launcher_item_app = com.microsoft.Edge.desktop
EOF

    chown -R "${EDGIFY_USER}:${EDGIFY_USER}" "${EDGIFY_HOME}/.config/tint2"

    echo ""
    echo "===================================================="
    echo " EdgifyOS installation complete!"
    echo " Reboot to enter the kiosk environment."
    echo "===================================================="
}

uninstall_edgifyos() {
    echo "[EdgifyOS] Starting uninstall..."

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "No EdgifyOS backup found. Cannot revert."
        exit 1
    fi

    [ -f "$BACKUP_DIR/lightdm.conf.bak" ] && cp "$BACKUP_DIR/lightdm.conf.bak" /etc/lightdm/lightdm.conf || rm -f /etc/lightdm/lightdm.conf
    [ -f "$BACKUP_DIR/openbox.desktop.bak" ] && cp "$BACKUP_DIR/openbox.desktop.bak" /usr/share/xsessions/openbox.desktop || rm -f /usr/share/xsessions/openbox.desktop

    EDGIFY_HOME=$(eval echo "~${EDGIFY_USER}")
    rm -rf "${EDGIFY_HOME}/.config/openbox" || true
    rm -rf "${EDGIFY_HOME}/.config/tint2" || true

    read -rp "Delete the 'edgify' user and its home directory? [y/N]: " DELUSER
    if [[ "$DELUSER" =~ ^[Yy]$ ]]; then
        deluser --remove-home "$EDGIFY_USER" || true
    fi

    echo ""
    echo "===================================================="
    echo " EdgifyOS has been removed."
    echo " System restored to normal Ubuntu behavior."
    echo "===================================================="
}

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

require_root

case "$1" in
    install) install_edgifyos ;;
    revert|uninstall) uninstall_edgifyos ;;
    "") main_menu ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
esac
