#!/usr/bin/env bash
set -e

echo "Starting SLSsteam installation..."

cd "$HOME" || exit 1

# Remove any previous clone
rm -rf SLSsteam

# Decode Git URL and clone
git_url_encoded="aHR0cHM6Ly9naXRodWIuY29tL0FjZVNMUy9TTFNzdGVhbQ=="
git_url=$(echo "$git_url_encoded" | base64 --decode)
echo "Cloning SLSsteam repository..."
git clone "$git_url"
cd SLSsteam || exit 1

echo "Building SLSsteam..."
make

echo "Installing SLSsteam..."
mkdir -p ~/.local/share/SLSsteam
cp bin/SLSsteam.so ~/.local/share/SLSsteam/SLSsteam.so

patch_line="export LD_AUDIT=\"$HOME/.local/share/SLSsteam/SLSsteam.so\""
echo "Patching /usr/bin/steam..."

# Backup original steam binary (recommended!)
cp /usr/bin/steam /usr/bin/steam.bak

# Remove any existing LD_AUDIT lines and add ours
sudo sed -i '/LD_AUDIT=.*SLSsteam.so/d' /usr/bin/steam
sudo sed -i "2i $patch_line" /usr/bin/steam

cd "$HOME" || exit 1
rm -rf SLSsteam

echo "============================================"
echo "SLSsteam installed and /usr/bin/steam patched successfully!"
echo "============================================"
