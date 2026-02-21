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
NEKO_VERSION="2.3.0"

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
echo "Installing Neko $NEKO_VERSION..."
echo "==============================================="
NEKO_TAG="${NEKO_VERSION//./-}"
curl -fsSL "https://github.com/HaxeFoundation/neko/releases/download/v${NEKO_TAG}/neko-${NEKO_VERSION}-osx64.tar.gz" -o neko.tar.gz
tar -xzf neko.tar.gz
NEKO_DIR="$(pwd)/$(tar -tzf neko.tar.gz | head -1 | cut -d/ -f1)"
export PATH="$NEKO_DIR:$PATH"
export DYLD_LIBRARY_PATH="$NEKO_DIR:${DYLD_LIBRARY_PATH:-}"
sudo cp "$NEKO_DIR"/libneko*.dylib /usr/local/lib/
rm neko.tar.gz
echo "Neko installed at: $NEKO_DIR"

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
echo "Installing libvlc via Homebrew..."
echo "==============================================="
brew install libvlc

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
