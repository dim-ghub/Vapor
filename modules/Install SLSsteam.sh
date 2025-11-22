#!/usr/bin/env bash
set -e

echo "Starting SLSsteam installation..."

SLS_DIR="$HOME/.local/share/SLSsteam"
TMP_DIR="$HOME/.local/share/Vapor/tmp"

rm -rf "$TMP_DIR"

mkdir -p "$SLS_DIR" "$TMP_DIR"

# Fetch latest release download URL from GitHub
echo "Fetching latest SLSsteam release..."
LATEST_URL=$(curl -s https://api.github.com/repos/AceSLS/SLSsteam/releases/latest \
    | grep "browser_download_url.*SLSsteam-Any.7z" \
    | cut -d '"' -f 4)

if [[ -z "$LATEST_URL" ]]; then
    echo "Failed to find latest release download URL."
    exit 1
fi

ARCHIVE="$TMP_DIR/SLSsteam-Any.7z"

echo "Downloading SLSsteam..."
curl -L "$LATEST_URL" -o "$ARCHIVE"

echo "Extracting SLSsteam..."
7z x "$ARCHIVE" -o"$TMP_DIR" >/dev/null
rm "$ARCHIVE"

# Move the .so file to target directory
mkdir -p "$SLS_DIR"
mv -f "$TMP_DIR/bin/SLSsteam.so" "$SLS_DIR/SLSsteam.so"

echo "Patching Steam launch script..."
STEAM_SCRIPT="/usr/lib/steam/bin_steam.sh"
EXPORT_LINE="export LD_AUDIT=\"$SLS_DIR/SLSsteam.so\""

# Make sure the script exists
if [[ ! -f "$STEAM_SCRIPT" ]]; then
    echo "Steam launch script not found at $STEAM_SCRIPT"
    exit 1
fi

# Backup original script if backup doesn't exist yet
sudo cp -n "$STEAM_SCRIPT" "${STEAM_SCRIPT}.bak"

# Only insert export line if it doesn't already exist
if ! grep -Fxq "$EXPORT_LINE" "$STEAM_SCRIPT"; then
    sudo sed -i '/cd "\$LAUNCHSTEAMDIR"/a '"$EXPORT_LINE" "$STEAM_SCRIPT"
    echo "Inserted LD_AUDIT line into Steam launch script."
else
    echo "LD_AUDIT line already present in Steam launch script, skipping."
fi

# Cleanup temporary folder
rm -rf "$TMP_DIR"

echo "============================================"
echo "SLSsteam installed and Steam launch script patched successfully!"
echo "============================================"
