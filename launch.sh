#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
GODOT_BIN="$BIN_DIR/godot_linux"

mkdir -p "$BIN_DIR"

if [ ! -f "$GODOT_BIN" ]; then
    echo "==================================================================="
    echo "          ⚡ GenEffects Studio - Instalación Rápida Linux ⚡"
    echo "==================================================================="
    echo "Descargando runtime portable de Godot 4.3..."
    
    ZIP_PATH="$BIN_DIR/godot_linux.zip"
    curl -L -o "$ZIP_PATH" "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip"
    unzip -q -o "$ZIP_PATH" -d "$BIN_DIR"
    rm -f "$ZIP_PATH"
    
    mv "$BIN_DIR"/Godot_v4.3*linux* "$GODOT_BIN" 2>/dev/null || true
    chmod +x "$GODOT_BIN"
    echo "Listo."
fi

exec "$GODOT_BIN" --path "$SCRIPT_DIR" "$@"
