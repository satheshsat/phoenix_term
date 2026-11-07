#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate executable
if [ -f "$DIR/termius_app" ]; then
    BIN="$DIR/termius_app"
elif [ -f "$DIR/../build/linux/x64/release/bundle/termius_app" ]; then
    BIN="$(cd "$DIR/../build/linux/x64/release/bundle" && pwd)/termius_app"
else
    BIN="termius_app"
fi

# Locate icon
if [ -f "$DIR/app_icon.png" ]; then
    ICON="$DIR/app_icon.png"
elif [ -f "$DIR/data/app_icon.png" ]; then
    ICON="$DIR/data/app_icon.png"
elif [ -f "$DIR/runner/app_icon.png" ]; then
    ICON="$DIR/runner/app_icon.png"
else
    ICON="$DIR/data/flutter_assets/assets/icon/app_icon.png"
fi

APPS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/1024x1024/apps"
PIXMAPS_DIR="$HOME/.local/share/pixmaps"

mkdir -p "$APPS_DIR" "$ICON_DIR" "$PIXMAPS_DIR"

if [ -f "$ICON" ]; then
    cp "$ICON" "$ICON_DIR/satcs.phoenix.terminal.png"
    cp "$ICON" "$PIXMAPS_DIR/satcs.phoenix.terminal.png"
fi

cat << EOF > "$APPS_DIR/satcs.phoenix.terminal.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Phoenix Terminal
GenericName=Terminal Client
Comment=The Modern Terminal for Devops & Sysadmins
Exec="$BIN" %U
Icon=$ICON_DIR/satcs.phoenix.terminal.png
Terminal=false
Categories=Utility;System;TerminalEmulator;
StartupWMClass=satcs.phoenix.terminal
EOF

chmod +x "$APPS_DIR/satcs.phoenix.terminal.desktop"

# Refresh desktop database if tools are available
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

echo "Phoenix Terminal has been successfully registered on your desktop!"

