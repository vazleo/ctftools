#!/bin/bash
# CTF Bundle Maker
# Downloads Ghidra and Burp Suite into downloads/ and packs everything
# into bundle.tar.gz ready to be deployed to lab machines.
#
# Run with: bash make_bundle.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOWNLOADS_DIR="$SCRIPT_DIR/downloads"
BUNDLE="$SCRIPT_DIR/bundle.tar.gz"

info() { echo "[*] $*"; }
ok()   { echo "[+] $*"; }

mkdir -p "$DOWNLOADS_DIR"

# ── Ghidra ────────────────────────────────────────────────────────────────────
if [[ -f "$DOWNLOADS_DIR/ghidra.zip" ]]; then
    echo "[-] downloads/ghidra.zip already exists — skipping"
else
    info "Fetching latest Ghidra release info from GitHub..."
    RELEASE_JSON=$(curl -fsSL https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest)
    GHIDRA_URL=$(echo "$RELEASE_JSON" | grep '"browser_download_url"' | grep '\.zip"' | head -1 | sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

    if [[ -z "$GHIDRA_URL" ]]; then
        echo "[!] Could not determine Ghidra download URL. Check your internet connection."
        exit 1
    fi

    info "Downloading Ghidra from $GHIDRA_URL ..."
    wget -q --show-progress -O "$DOWNLOADS_DIR/ghidra.zip" "$GHIDRA_URL"
    ok "Ghidra saved to downloads/ghidra.zip"
fi

# ── Burp Suite ────────────────────────────────────────────────────────────────
if [[ -f "$DOWNLOADS_DIR/burpsuite.jar" ]]; then
    echo "[-] downloads/burpsuite.jar already exists — skipping"
else
    info "Downloading Burp Suite Community JAR..."
    wget -q --show-progress \
        -O "$DOWNLOADS_DIR/burpsuite.jar" \
        "https://portswigger.net/burp/releases/download?product=community&type=Jar"
    ok "Burp Suite saved to downloads/burpsuite.jar"
fi

# ── Pack bundle ───────────────────────────────────────────────────────────────
info "Packing bundle.tar.gz..."
tar -czf "$BUNDLE" \
    -C "$SCRIPT_DIR" \
    install_ctf.sh \
    uninstall_ctf.sh \
    .env \
    downloads/

ok "Bundle created: $BUNDLE ($(du -h "$BUNDLE" | cut -f1))"
echo ""
echo "================================================================"
echo " Run deploy.sh to push this bundle to all lab machines."
echo "================================================================"
