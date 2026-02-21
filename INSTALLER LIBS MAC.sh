#!/bin/bash
# ===============================================
#   FNF / HaxeFlixel Environment Setup — macOS
# ===============================================
# Prerequisites:
#   - Git          (xcode-select --install)
#   - Homebrew     (https://brew.sh)
#   - Neko + Haxe  (installed automatically below)
#   - libvlc       (installed automatically below)
# ===============================================

set -e  # Stop the script if any command fails

HAXE_VERSION="4.3.6"

echo "==============================================="
echo "   FNF / HaxeFlixel Environment Setup — macOS"
echo "==============================================="
echo ""
echo "This script will install a STABLE and COMPATIBLE"
echo "HaxeFlixel environment for FNF-based projects."
echo ""
echo "Make sure the following are already installed:"
echo "  - Git"
echo "  - Homebrew"
echo ""
read -rp "Press ENTER to continue..."

# ── Neko ─────────────────────────────────────────
# haxelib is a Neko binary — it MUST be installed first
# or haxelib will crash with "libneko.2.dylib not found".
echo ""
echo "==============================================="
echo "Installing Neko via Homebrew..."
echo "==============================================="
brew install neko
# On Apple Silicon, Homebrew installs to /opt/homebrew instead of /usr/local.
# haxelib has @rpath hardcoded to /usr/local/lib, so we symlink it there.
sudo mkdir -p /usr/local/lib
sudo ln -sf "$(brew --prefix neko)/lib/libneko.2.dylib" /usr/local/lib/libneko.2.dylib

# ── Haxe ─────────────────────────────────────────
echo ""
echo "==============================================="
echo "Installing Haxe $HAXE_VERSION..."
echo "==============================================="
curl -fsSL "https://github.com/HaxeFoundation/haxe/releases/download/${HAXE_VERSION}/haxe-${HAXE_VERSION}-osx.tar.gz" -o haxe.tar.gz
tar -xzf haxe.tar.gz
HAXE_DIR="$(pwd)/$(tar -tzf haxe.tar.gz | head -1 | cut -d/ -f1)"
export PATH="$HAXE_DIR:$PATH"
export HAXE_STD_PATH="$HAXE_DIR/std"
mkdir -p ~/haxelib
"$HAXE_DIR/haxelib" setup ~/haxelib
rm haxe.tar.gz
echo "Haxe installed at: $HAXE_DIR"

# ── libvlc ──────────────────────────────────────
echo ""
echo "==============================================="
echo "Installing VLC (libvlc) via Homebrew cask..."
echo "==============================================="
brew install --cask vlc
echo "VLC installed at: /Applications/VLC.app"
ls /Applications/VLC.app/Contents/MacOS/lib/ | grep vlc || true

# ── Clean conflicting libraries ──────────────────
echo ""
echo "==============================================="
echo "Cleaning conflicting libraries..."
echo "==============================================="
haxelib remove flixel-ui    2>/dev/null || true
haxelib remove flixel       2>/dev/null || true
haxelib remove openfl       2>/dev/null || true
haxelib remove lime         2>/dev/null || true

# ── Core dependencies ────────────────────────────
echo ""
echo "==============================================="
echo "Installing core dependencies..."
echo "==============================================="
haxelib install hxcpp
haxelib install lime 8.0.2
haxelib install openfl 9.2.2

haxelib set lime 8.0.2
haxelib set openfl 9.2.2

# ── HaxeFlixel ───────────────────────────────────
echo ""
echo "==============================================="
echo "Installing HaxeFlixel..."
echo "==============================================="
haxelib install flixel 5.3.1
haxelib set flixel 5.3.1

haxelib install flixel-addons 3.2.2
haxelib install flixel-ui 2.6.1
haxelib install flixel-tools 1.5.1

# ── Additional libraries ─────────────────────────
echo ""
echo "==============================================="
echo "Installing additional libraries..."
echo "==============================================="
haxelib install actuate
haxelib install hscript
haxelib install hxcpp-debug-server

# ── Setup Lime and Flixel ────────────────────────
echo ""
echo "==============================================="
echo "Setting up Lime and Flixel..."
echo "==============================================="
haxelib run lime setup -y
haxelib run lime setup flixel
haxelib run flixel-tools setup

# ── Discord RPC and flxanimate ───────────────────
echo ""
echo "==============================================="
echo "Installing Discord RPC and flxanimate..."
echo "==============================================="
haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate

# ── Re-lock library versions ─────────────────────
echo ""
echo "==============================================="
echo "Re-locking library versions..."
echo "==============================================="
haxelib set lime 8.0.2
haxelib set openfl 9.2.2
haxelib set flixel 5.3.1
haxelib set flixel-ui 2.6.1
haxelib set flixel-addons 3.2.2

# ── Rebuild Lime for arm64 ───────────────────────
echo ""
echo "==============================================="
echo "Rebuilding Lime native libs for arm64..."
echo "==============================================="
# The prebuilt .ndll inside the haxelib package is x86_64.
# This recompiles it for the current architecture (arm64).
haxelib run lime rebuild mac

# ── Done ─────────────────────────────────────────
echo ""
echo "==============================================="
echo "Setup completed successfully!"
echo "==============================================="
echo ""
echo "Installed versions:"
echo "  - Lime:           8.0.2"
echo "  - OpenFL:         9.2.2"
echo "  - Flixel:         5.3.1"
echo "  - Flixel-UI:      2.6.1"
echo "  - Flixel-Addons:  3.2.2"
echo ""
echo "You are now ready to compile your project with:"
echo "  haxelib run lime build mac -final"
echo ""
read -rp "Press ENTER to exit."
