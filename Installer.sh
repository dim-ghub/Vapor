#!/usr/bin/env bash
set -e

# Variables
REPO_URL="https://github.com/dim-ghub/Vapor.git"
INSTALL_DIR="$HOME/.local/share/Vapor"
DESKTOP_FILE="$INSTALL_DIR/Vapor.desktop"
APPLICATIONS_DIR="$HOME/.local/share/applications"
DEPOTDOWNLOADER_URL_API="https://api.github.com/repos/dim-ghub/DepotDownloaderMod/releases/latest"

echo "Creating install directory at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# 1. Clone the repo
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Vapor repo already exists. Pulling latest changes..."
    git -C "$INSTALL_DIR" pull
else
    echo "Cloning Vapor repo..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# 2. Download latest DepotDownloaderMod release (with debug)
echo "Fetching latest DepotDownloaderMod release data..."
API_URL="https://api.github.com/repos/dim-ghub/DepotDownloaderMod/releases/latest"
json=$(curl -sL "$API_URL")

if [ -z "$json" ]; then
  echo "Error: Empty response from GitHub API at $API_URL"
  exit 1
fi

echo "Raw JSON (first 200 chars): $(echo "$json" | head -c200)…"

LATEST_URL=$(echo "$json" \
  | grep '"browser_download_url"' \
  | grep -i DepotDownloaderMod \
  | cut -d '"' -f4 \
  | head -n1)

if [ -z "$LATEST_URL" ]; then
  echo "Unable to locate a download URL in the release JSON."
  echo "Complete JSON:"
  echo "$json"
  exit 1
fi

echo "Download URL found: $LATEST_URL"
echo "Downloading …"
curl -L "$LATEST_URL" -o "$INSTALL_DIR/DepotDownloaderMod"

if [ ! -s "$INSTALL_DIR/DepotDownloaderMod" ]; then
  echo "Downloaded file is empty or missing: $INSTALL_DIR/DepotDownloaderMod"
  exit 1
fi

chmod +x "$INSTALL_DIR/DepotDownloaderMod"
echo "DepotDownloaderMod downloaded and executable set."

echo "Downloading DepotDownloaderMod..."
curl -L "$LATEST_URL" -o "$INSTALL_DIR/DepotDownloaderMod"
chmod +x "$INSTALL_DIR/DepotDownloaderMod"

# 3. Edit Vapor.desktop file
if [ -f "$DESKTOP_FILE" ]; then
    echo "Updating Vapor.desktop..."
    sed -i "s|^Exec=.*|Exec=bash $INSTALL_DIR/main.sh|" "$DESKTOP_FILE"
    sed -i "s|^Icon=.*|Icon=$INSTALL_DIR/assets/Vapor.svg|" "$DESKTOP_FILE"

    # Move desktop file to applications directory
    echo "Installing desktop shortcut..."
    mkdir -p "$APPLICATIONS_DIR"
    mv "$DESKTOP_FILE" "$APPLICATIONS_DIR/"
    chmod +x "$APPLICATIONS_DIR/$(basename "$DESKTOP_FILE")"
else
    echo "Warning: $DESKTOP_FILE not found, skipping desktop file edit."
fi

# 4. Make scripts executable
echo "Making scripts executable..."
chmod +x "$INSTALL_DIR/setup.sh" "$INSTALL_DIR/main.sh" "$INSTALL_DIR/storage_depotdownloadermod.py"

echo "Installation complete!"
echo "You can now launch Vapor from your application menu."
