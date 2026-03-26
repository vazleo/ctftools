#!/bin/bash
# CTF Lab Scanner
# Ping scans the lab subnet and writes the last octets of live hosts to ips.txt.
#
# Run with: bash scan.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
else
    echo "[!] .env file not found at $SCRIPT_DIR/.env"
    exit 1
fi

if ! command -v nmap &>/dev/null; then
    echo "[!] nmap is not installed. Run: sudo apt-get install -y nmap"
    exit 1
fi

SUBNET="$IP_PREFIX.0/24"
OUTPUT="$SCRIPT_DIR/ips.txt"

echo "[*] Scanning $SUBNET for live hosts..."
nmap -sn "$SUBNET" -oG - \
    | awk '/Up$/{print $2}' \
    | grep "^$IP_PREFIX\." \
    | awk -F. '{print $4}' \
    | sort -n > "$OUTPUT"

COUNT=$(wc -l < "$OUTPUT")
echo "[+] Found $COUNT live hosts. Last octets saved to ips.txt:"
cat "$OUTPUT"
