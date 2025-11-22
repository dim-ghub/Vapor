#!/usr/bin/env bash
set -e

# Define paths
REPO_URL="https://github.com/xamionex/SLScheevo.git"
INSTALL_DIR="$HOME/.local/share/Vapor/SLScheevo"
RUN_SCRIPT="$INSTALL_DIR/run.sh"
SAVED_LOGINS="$INSTALL_DIR/data/saved_logins.encrypted"

# Clone or update repository
if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    echo "Cloning SLScheevo into $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    echo "SLScheevo already exists. Pulling latest changes..."
    git -C "$INSTALL_DIR" pull --rebase
fi

# Check for saved logins and run the script accordingly
if [[ -f "$SAVED_LOGINS" ]]; then
    echo "Saved logins found. Running in silent mode..."
    bash "$RUN_SCRIPT" --silent
else
    echo "No saved logins found. Running normally..."
    bash "$RUN_SCRIPT"
fi
