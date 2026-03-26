#!/bin/bash
# CTF Tools Installer
# Creates user 'ctf' and installs tools in their home directory.
# Run with: sudo bash install_ctf.sh

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
else
    echo "[!] .env file not found at $SCRIPT_DIR/.env"
    exit 1
fi

CTF_USER="${CTF_USER:-ctf}"
TOOLS_DIR="/home/$CTF_USER/tools"
VENV_DIR="/home/$CTF_USER/venv"

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { echo "[*] $*"; }
ok()    { echo "[+] $*"; }
skip()  { echo "[-] $* — skipping (already done)"; }

as_ctf() { sudo -u "$CTF_USER" "$@"; }

# ── 0. Root check ─────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Run this script with sudo: sudo bash $0"
    exit 1
fi

# ── 1. Create user ────────────────────────────────────────────────────────────
info "Creating user '$CTF_USER'..."
if id "$CTF_USER" &>/dev/null; then
    skip "User '$CTF_USER' already exists"
else
    useradd -m -s /bin/bash "$CTF_USER"
    ok "User '$CTF_USER' created"
fi
echo "$CTF_USER:$CTF_PASS" | chpasswd
ok "Password set"

mkdir -p "$TOOLS_DIR"
chown "$CTF_USER:$CTF_USER" "$TOOLS_DIR"

# ── 2. System packages ────────────────────────────────────────────────────────
info "Installing apt packages..."
apt-get update -qq
apt-get install -y \
    gdb git wget curl unzip \
    python3 python3-pip python3-venv \
    libimage-exiftool-perl \
    openjdk-21-jdk
ok "apt packages installed"

# ── 3. pwndbg ─────────────────────────────────────────────────────────────────
PWNDBG_DIR="$TOOLS_DIR/pwndbg"
info "Installing pwndbg..."
if [[ -d "$PWNDBG_DIR" ]]; then
    skip "pwndbg directory already exists at $PWNDBG_DIR"
else
    as_ctf git clone --depth=1 https://github.com/pwndbg/pwndbg "$PWNDBG_DIR"
    # setup.sh must run as root to install system deps, but configures gdb for ctf user
    # Must cd into the pwndbg dir first — uv looks for pyproject.toml in the cwd
    (cd "$PWNDBG_DIR" && HOME="/home/$CTF_USER" SUDO_USER="$CTF_USER" bash setup.sh)
    ok "pwndbg installed"
fi

# ── 4. Ghidra ─────────────────────────────────────────────────────────────────
info "Installing Ghidra..."
if [[ -n "$(find "$TOOLS_DIR" -maxdepth 1 -type d -name "ghidra_*" 2>/dev/null)" ]]; then
    skip "Ghidra already installed in $TOOLS_DIR"
else
    if [[ -f "$SCRIPT_DIR/downloads/ghidra.zip" ]]; then
        info "Using bundled downloads/ghidra.zip..."
        cp "$SCRIPT_DIR/downloads/ghidra.zip" /tmp/ghidra.zip
    else
        info "Fetching latest Ghidra release info from GitHub..."
        RELEASE_JSON=$(curl -fsSL https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest)
        GHIDRA_URL=$(echo "$RELEASE_JSON" | grep '"browser_download_url"' | grep '\.zip"' | head -1 | sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

        if [[ -z "$GHIDRA_URL" ]]; then
            echo "[!] Could not determine Ghidra download URL. Check your internet connection and try again."
            exit 1
        fi

        info "Downloading Ghidra from $GHIDRA_URL ..."
        wget -q --show-progress -O /tmp/ghidra.zip "$GHIDRA_URL"
    fi
    unzip -q /tmp/ghidra.zip -d "$TOOLS_DIR"
    rm /tmp/ghidra.zip

    # Wrapper script — finds ghidraRun inside whichever versioned dir was extracted
    cat > "$TOOLS_DIR/ghidra" <<'EOF'
#!/bin/bash
GHIDRA_RUN=$(find "$(dirname "$(readlink -f "$0")")" -maxdepth 2 -name "ghidraRun" | head -1)
exec "$GHIDRA_RUN" "$@"
EOF
    chmod +x "$TOOLS_DIR/ghidra"
    chown -R "$CTF_USER:$CTF_USER" "$TOOLS_DIR"/ghidra_* "$TOOLS_DIR/ghidra"
    ok "Ghidra installed in $TOOLS_DIR"
fi

# ── 5. Burp Suite Community ───────────────────────────────────────────────────
BURP_JAR="$TOOLS_DIR/burpsuite.jar"
info "Installing Burp Suite Community..."
if [[ -f "$BURP_JAR" ]]; then
    skip "Burp Suite JAR already exists at $BURP_JAR"
else
    if [[ -f "$SCRIPT_DIR/downloads/burpsuite.jar" ]]; then
        info "Using bundled downloads/burpsuite.jar..."
        cp "$SCRIPT_DIR/downloads/burpsuite.jar" "$BURP_JAR"
    else
        info "Downloading Burp Suite Community JAR..."
        wget -q --show-progress \
            -O "$BURP_JAR" \
            "https://portswigger.net/burp/releases/download?product=community&type=Jar"
    fi

    # Wrapper script so 'burpsuite' is on PATH
    cat > "$TOOLS_DIR/burpsuite" <<'EOF'
#!/bin/bash
java -jar "$(dirname "$(readlink -f "$0")")/burpsuite.jar" "$@"
EOF
    chmod +x "$TOOLS_DIR/burpsuite"
    chown "$CTF_USER:$CTF_USER" "$BURP_JAR" "$TOOLS_DIR/burpsuite"
    ok "Burp Suite installed at $BURP_JAR"
fi

# ── 6. Python venv + pip packages ────────────────────────────────────────────
info "Setting up Python venv and installing pip packages..."
if [[ -d "$VENV_DIR" ]]; then
    skip "venv already exists at $VENV_DIR"
else
    as_ctf python3 -m venv "$VENV_DIR"
    ok "venv created at $VENV_DIR"
fi

info "Installing pwntools and pycryptodome..."
as_ctf "$VENV_DIR/bin/pip" install --quiet --upgrade pip
as_ctf "$VENV_DIR/bin/pip" install --quiet pwntools pycryptodome
ok "Python packages installed"

# ── 7. Configure .bashrc ──────────────────────────────────────────────────────
BASHRC="/home/$CTF_USER/.bashrc"
MARKER="# CTF tools setup"
info "Configuring .bashrc..."
if grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    skip ".bashrc already configured"
else
    cat >> "$BASHRC" <<EOF

$MARKER
export PATH="\$HOME/tools:\$PATH"
source "\$HOME/venv/bin/activate"
EOF
    ok ".bashrc configured"
fi

# ── 8. Final ownership fix ────────────────────────────────────────────────────
chown -R "$CTF_USER:$CTF_USER" "/home/$CTF_USER"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "================================================================"
echo " Installation complete!"
echo "  User:     $CTF_USER"
echo "  Password: $CTF_PASS"
echo "  Tools:    $TOOLS_DIR"
echo ""
echo "  Switch to the CTF user with:  su - $CTF_USER"
echo "  Verify tools:"
echo "    exiftool -ver"
echo "    gdb --version"
echo "    python3 -c \"import pwn; print('pwntools ok')\""
echo "    python3 -c \"from Crypto.Cipher import AES; print('pycryptodome ok')\""
echo "    ghidra &"
echo "    burpsuite &"
echo "================================================================"
