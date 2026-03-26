#!/bin/bash
# CTF Deploy
# Copies bundle.tar.gz to each lab machine and runs install_ctf.sh with sudo.
#
# Prerequisites:
#   - bundle.tar.gz exists (run make_bundle.sh first)
#   - ips.txt exists (run scan.sh first, or create manually)
#   - sshpass is installed: sudo apt-get install -y sshpass
#
# Run with: bash deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
else
    echo "[!] .env file not found at $SCRIPT_DIR/.env"
    exit 1
fi

BUNDLE="$SCRIPT_DIR/bundle.tar.gz"
IPS_FILE="$SCRIPT_DIR/ips.txt"
REMOTE_DIR="/home/$LAB_USER/ctf-install"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# ── Pre-flight checks ─────────────────────────────────────────────────────────
if ! command -v sshpass &>/dev/null; then
    echo "[!] sshpass is not installed. Run: sudo apt-get install -y sshpass"
    exit 1
fi

if [[ ! -f "$BUNDLE" ]]; then
    echo "[!] bundle.tar.gz not found. Run make_bundle.sh first."
    exit 1
fi

if [[ ! -f "$IPS_FILE" ]]; then
    echo "[!] ips.txt not found. Run scan.sh first or create it manually."
    exit 1
fi

TOTAL=$(wc -l < "$IPS_FILE")
echo "[*] Deploying to $TOTAL machines..."
echo ""

COUNT=0
FAILED=()

while IFS= read -r octet; do
    IP="$IP_PREFIX.$octet"
    COUNT=$((COUNT + 1))
    echo "── [$COUNT/$TOTAL] $IP ──────────────────────────────────────"

    # Copy bundle as lab user
    echo "[*] Uploading bundle..."
    sshpass -p "$LAB_PASS" scp $SSH_OPTS \
        "$BUNDLE" \
        "$LAB_USER@$IP:~/" || { echo "[!] SCP failed for $IP"; FAILED+=("$IP"); continue; }

    # Extract bundle as lab user
    echo "[*] Extracting bundle..."
    sshpass -p "$LAB_PASS" ssh $SSH_OPTS \
        "$LAB_USER@$IP" \
        "mkdir -p $REMOTE_DIR && tar -xzf ~/bundle.tar.gz -C $REMOTE_DIR && rm ~/bundle.tar.gz" \
        || { echo "[!] Extract failed for $IP"; FAILED+=("$IP"); continue; }

    # Run install script as sudo user
    echo "[*] Running install..."
    sshpass -p "$SUDO_PASS" ssh $SSH_OPTS \
        "$SUDO_USER@$IP" \
        "echo '$SUDO_PASS' | sudo -S bash $REMOTE_DIR/install_ctf.sh" \
        || { echo "[!] Install failed for $IP"; FAILED+=("$IP"); continue; }

    echo "[+] Done: $IP"
    echo ""
done < "$IPS_FILE"

# ── Summary ───────────────────────────────────────────────────────────────────
echo "================================================================"
echo " Deployment complete: $((COUNT - ${#FAILED[@]}))/$COUNT succeeded"
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo " Failed machines:"
    for ip in "${FAILED[@]}"; do
        echo "   - $ip"
    done
fi
echo "================================================================"
