EdgifyOS
A lightweight, ChromeOS‑style environment for Ubuntu 22.04 that boots directly into Microsoft Edge using a minimal Openbox session. Designed for kiosks, labs, shared devices, and distraction‑free browsing.

EdgifyOS replaces the full Ubuntu desktop with a fast, clean, browser‑first interface powered by Flatpak Edge.

Features
Boots directly into a dedicated edgify user

Uses LightDM autologin for instant startup

Minimal Openbox session with Tint2 panel

Microsoft Edge (Flatpak) launches maximized on login

No APT Edge repo required

Installer prompts you to set a password for the edgify user

Fully reversible — uninstall restores Ubuntu behavior

Installation
Run the installer directly:

===

curl -fsSL https://raw.githubusercontent.com/inartaly/EdgifyOS/main/edgify-bootstrap.sh | sudo bash -s install

===

The script will:

Install curl if missing

Update the system

Install LightDM, Openbox, Tint2, and Flatpak

Switch Ubuntu to LightDM

Install Microsoft Edge (Flatpak)

Create the edgify user and prompt for a password

Configure autologin + Openbox session

Set up Tint2 and Edge autostart

Reboot when finished.
