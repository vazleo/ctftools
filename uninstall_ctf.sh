#!/bin/bash
# CTF Tools Uninstaller
# Removes the 'ctf' user and all associated files.
# Run with: sudo bash uninstall_ctf.sh

set -euo pipefail

CTF_USER="ctf"

if [[ $EUID -ne 0 ]]; then
    echo "Run this script with sudo: sudo bash $0"
    exit 1
fi

if ! id "$CTF_USER" &>/dev/null; then
    echo "User '$CTF_USER' does not exist — nothing to do."
    exit 0
fi

echo "[*] Removing user '$CTF_USER' and home directory..."
# Kill any running processes by this user first
pkill -u "$CTF_USER" 2>/dev/null || true
# Delete user and home dir
userdel -r "$CTF_USER"
echo "[+] Done. User '$CTF_USER' and /home/$CTF_USER removed."
echo ""
echo "Note: system packages installed by install_ctf.sh (gdb, JDK, exiftool, etc.)"
echo "were intentionally left in place — remove them manually with apt if needed."
