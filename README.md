# CTF Tools Installer

Bash scripts to set up and tear down a CTF environment on Linux (Ubuntu/Mint) lab machines. Designed to be run once with sudo — creates an isolated `ctf` user and installs all tools under their home directory.

## Tools installed

| Tool | Purpose |
|------|---------|
| **Ghidra** | Reverse engineering — disassemble and decompile binaries |
| **Burp Suite Community** | Web — intercept and modify HTTP traffic |
| **pwndbg** | Binary exploitation — GDB with extra commands for pwn |
| **pwntools** | Python library for scripting exploits |
| **pycryptodome** | Python library for cryptography challenges |
| **exiftool** | Forensics — read and analyze file metadata |

## Requirements

- Ubuntu 22.04+ or Linux Mint 21+ (apt-based)
- Internet access during installation
- Run with `sudo`

## Usage

### Configure

Copy `.env.example` to `.env` and set your password:

```bash
cp .env.example .env
nano .env
```

```
CTF_USER=ctf
CTF_PASS=your_password_here
```

### Install

```bash
sudo bash install_ctf.sh
```

Creates user `ctf`, installs all tools under `/home/ctf/`, and configures the environment. Takes a few minutes due to large downloads (Ghidra ~486MB, Burp Suite ~645MB).

### Uninstall

```bash
sudo bash uninstall_ctf.sh
```

Deletes the `ctf` user and their entire home directory. System packages (gdb, JDK, exiftool) are left in place.

## Logging in as the CTF user

From the desktop login screen, log in as `ctf` / `ctfgris`.

Or from a terminal:
```bash
su - ctf
```

The Python venv activates automatically and all tools are available on PATH — no extra setup needed.

## Using the tools

**Ghidra** — reverse engineering
```bash
ghidra &
```
New project → import your binary → double-click it → CodeBrowser → decompiler panel on the right.

**Burp Suite** — web exploitation
```bash
burpsuite &
```
Use a temporary project → Proxy tab → Open Browser → traffic flows through Burp.

**pwndbg** — binary debugging
```bash
gdb ./binary
```
pwndbg loads automatically on top of GDB. Useful extra commands: `checksec`, `cyclic`, `vmmap`, `heap`, `stack`.

**pwntools** — exploit scripting
```python
from pwn import *
p = process('./binary')      # or remote('host', port)
p.sendline(b'your payload')
p.interactive()
```

**pycryptodome** — crypto challenges
```python
from Crypto.Cipher import AES
from Crypto.Util.number import long_to_bytes, bytes_to_long
```

**exiftool** — file metadata
```bash
exiftool suspicious_image.png
```

## How the environment works

Two lines in `/home/ctf/.bashrc` handle all of this automatically on login:

```bash
export PATH="$HOME/tools:$PATH"   # makes ghidra, burpsuite etc. callable by name
source "$HOME/venv/bin/activate"  # activates the Python venv with pwntools/pycryptodome
```
