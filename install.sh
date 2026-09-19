#!/bin/bash

set -euo pipefail

DMG_NAME="${1:-BrewSnap.dmg}"
MOUNT_POINT="/Volumes/BrewSnap"
APP_NAME="BrewSnap.app"
DEST="/Applications/$APP_NAME"

echo "======================================"
echo "        BrewSnap Installer"
echo "======================================"
echo ""

if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: BrewSnap can only be installed on macOS."
    exit 1
fi

echo "Searching for '$DMG_NAME'..."

CURRENT_DIR="$(pwd)"
CURRENT_DMG="$CURRENT_DIR/$DMG_NAME"
DMG=""

if [[ -f "$CURRENT_DMG" ]]; then
    DMG="$CURRENT_DMG"
    echo "Found DMG in current directory:"
    echo "  $DMG"
else
    echo "DMG not found in current directory."
    echo "Searching your home directory..."
    echo ""

    NEWEST_FILE=""
    NEWEST_TIME=0

    while IFS= read -r file; do
        FILE_TIME=$(stat -f "%m" "$file" 2>/dev/null || echo 0)

        if [[ "$FILE_TIME" -gt "$NEWEST_TIME" ]]; then
            NEWEST_TIME="$FILE_TIME"
            NEWEST_FILE="$file"
        fi
    done < <(
        find "$HOME" \
            -type f \
            -name "$DMG_NAME" \
            -not -path "$HOME/Library/*" \
            -not -path "$HOME/.Trash/*" \
            2>/dev/null
    )

    if [[ -z "$NEWEST_FILE" ]]; then
        echo "Error: Could not find '$DMG_NAME'."
        echo ""
        echo "Make sure the DMG has been downloaded and try again."
        exit 1
    fi

    DMG="$NEWEST_FILE"

    echo "Found DMG:"
    echo "  $DMG"
    echo ""
fi

if [[ ! -f "$DMG" ]]; then
    echo "Error: DMG does not exist:"
    echo "$DMG"
    exit 1
fi

if [[ -d "$MOUNT_POINT" ]]; then
    echo "An existing BrewSnap volume was detected."
    echo "Unmounting it first..."

    if ! hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null; then
        echo "Error: Could not unmount existing BrewSnap volume."
        exit 1
    fi
fi

echo "Mounting DMG..."

hdiutil attach "$DMG" \
    -nobrowse \
    -quiet

echo "DMG mounted."
echo ""

APP="$MOUNT_POINT/$APP_NAME"

if [[ ! -d "$APP" ]]; then
    echo "Error: '$APP_NAME' was not found inside the DMG."
    echo ""
    echo "DMG contents:"
    ls -la "$MOUNT_POINT"

    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true

    exit 1
fi

echo "Installing $APP_NAME..."

if [[ -d "$DEST" ]]; then
    echo "An existing installation was found."
    echo "Removing previous version..."
    rm -rf "$DEST"
fi

cp -R "$APP" "$DEST"

echo "Application copied to:"
echo "  $DEST"
echo ""

echo "Removing macOS quarantine attribute..."

if xattr -dr com.apple.quarantine "$DEST" 2>/dev/null; then
    echo "Quarantine attribute removed."
else
    echo "Warning: Could not remove quarantine attribute."
fi

echo ""
echo "Unmounting DMG..."

if hdiutil detach "$MOUNT_POINT" -quiet; then
    echo "DMG unmounted."
else
    echo "Warning: Could not unmount DMG automatically."
fi

echo ""
echo "Launching BrewSnap..."

open "$DEST"

echo ""
echo "======================================"
echo "  BrewSnap installed successfully!"
echo "======================================"
echo ""
echo "Installed at:"
echo "  $DEST"
echo ""
