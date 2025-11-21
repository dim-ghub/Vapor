#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/dim-ghub/Vapor.git"
INSTALL_DIR="$HOME/.local/share/Vapor"
DESKTOP_FILE="$INSTALL_DIR/Vapor.desktop"
APPLICATIONS_DIR="$HOME/.local/share/applications"
DEPOTDOWNLOADER_URL_API="https://api.github.com/repos/dim-ghub/DepotDownloaderMod/releases/latest"

echo "Creating install directory at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Vapor repo already exists. Pulling latest changes..."
    git -C "$INSTALL_DIR" pull
else
    echo "Cloning Vapor repo..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

echo "Downloading DepotDownloaderMod..."
curl -L "https://github.com/dim-ghub/Vapor/releases/download/Binaries/DepotDownloaderMod" -o "$HOME/.local/share/Vapor/DepotDownloaderMod"

if [ ! -s "$INSTALL_DIR/DepotDownloaderMod" ]; then
    echo "Error: Failed to download DepotDownloaderMod"
    exit 1
fi

chmod +x "$INSTALL_DIR/DepotDownloaderMod"
echo "DepotDownloaderMod downloaded and made executable."

if [ -f "$DESKTOP_FILE" ]; then
    echo "Updating Vapor.desktop..."
    sed -i "s|^Exec=.*|Exec=bash $INSTALL_DIR/main.sh|" "$DESKTOP_FILE"
    sed -i "s|^Icon=.*|Icon=$INSTALL_DIR/assets/Vapor.svg|" "$DESKTOP_FILE"

    echo "Installing desktop shortcut..."
    mkdir -p "$APPLICATIONS_DIR"
    mv "$DESKTOP_FILE" "$APPLICATIONS_DIR/"
    chmod +x "$APPLICATIONS_DIR/$(basename "$DESKTOP_FILE")"
else
    echo "Warning: $DESKTOP_FILE not found, skipping desktop file edit."
fi

echo "Making scripts executable..."
chmod +x "$INSTALL_DIR/setup.sh" "$INSTALL_DIR/main.sh" "$INSTALL_DIR/storage_depotdownloadermod.py"

echo "Running setup script to prepare virtual environment and dependencies..."
bash "$INSTALL_DIR/setup.sh"

echo "Installation and setup complete!"
echo "You can now launch Vapor from your application menu."
