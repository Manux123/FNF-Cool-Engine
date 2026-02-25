#!/bin/bash

echo ""
echo " ======================================"
echo "  Cool Engine HScript - VS Code Setup"
echo " ======================================"
echo ""

# Verificar que VS Code está instalado
if ! command -v code &> /dev/null; then
    echo " [ERROR] VS Code was not found in the PATH."
    echo ""
    echo " Download it from: https://code.visualstudio.com/"
    echo ""
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VSIX_PATH="$SCRIPT_DIR/tools/cool-engine-hscript.vsix"

# Verificar que existe el .vsix
if [ ! -f "$VSIX_PATH" ]; then
    echo " [ERROR] The extension could not be installed."
    echo " Make sure 'tools/cool-engine-hscript.vsix' exists."
    echo ""
    exit 1
fi

# Instalar la extensión
echo " [1/2] Installing HScript extension..."
code --install-extension "$VSIX_PATH" --force

if [ $? -ne 0 ]; then
    echo ""
    echo " [ERROR] The extension could not be installed."
    echo ""
    exit 1
fi

# Abrir el proyecto
echo ""
echo " [2/2] Opening a project in VS Code..."
code "$SCRIPT_DIR"

echo ""
echo " Done! The HScript extension is now active."
echo ""
