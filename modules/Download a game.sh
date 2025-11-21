#!/usr/bin/env bash
set -e

# Ensure script is run interactively
if [[ ! -t 0 ]]; then
    echo "This script must be run interactively!"
    exit 1
fi

# Switch to Vapor directory
VAPOR_DIR="$HOME/.local/share/Vapor"
cd "$VAPOR_DIR" || { echo "Failed to enter $VAPOR_DIR"; exit 1; }

VENV_DIR="$VAPOR_DIR/venv"
PYTHON_BIN="$VENV_DIR/bin/python"
SCRIPT="$VAPOR_DIR/storage_depotdownloadermod.py"
DEPOT_BASE="$VAPOR_DIR/depots"

SKIP_INTRO=0

# --- FLAG HANDLING ---
for arg in "$@"; do
    case "$arg" in
        --skip-intro)
            SKIP_INTRO=1
            ;;
    esac
done

# Function to search Steam for a game by name
search_steam() {
    local query="$1"
    echo "Searching Steam for '$query'..."
    local results
    results=$(curl -s "https://store.steampowered.com/api/storesearch/?term=$(echo "$query" | sed 's/ /%20/g')&l=english&cc=US")
    
    mapfile -t apps < <(echo "$results" | jq -r '.items[] | "\(.name) [AppID: \(.id)]"')
    
    if [[ ${#apps[@]} -eq 0 ]]; then
        echo "No results found for '$query'."
        exit 1
    fi

    echo "Select a game:"
    select choice in "${apps[@]}"; do
        if [[ -n "$choice" ]]; then
            APPID=$(echo "$choice" | grep -oP '\[AppID: \K[0-9]+')
            break
        fi
    done
}
clear
if [[ $SKIP_INTRO -eq 0 ]]; then
    clear
    cat <<'EOF'

████▓▓▒░░     ░░                                            ░ ░ ░ ░ ░░░░░░░░░░░ ░░░░░░░░░░▒▒▓▓██████
█████▒▒░░                 ░                                 ░  ░ ░░░ ░░░░░░░░░░ ░░░ ░░░░░░░▒▓▓███▓██
█████▓▒░   ░░░             ░                           ░░  ░       ░░░░░░░░░  ░░░ ░░░░░░░░▒░▒▓▓█████
█████▓▒░░  ░                ░                                    ░░░░░░░░░░ ░░░░░░░░░░ ░░░░▒▒▒▓█████
█████▓▓░░░  ░                      ░ ░░ ░                       ░ ░░░░░░░░ ░ ░ ░░░░░░░░░░░░░▒░▒▓█▓▓█
██▓██▒▓░   ░                         ░ ░░                       ░ ░░░░░░░░░ ░░░░░ ░░░░░░░░░░▒▒░▓▓▓▓█
████▓█▓▓░░ ░           ░░       ░░   ░  ░                       ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▓▓▓█
██████▓▒░ ░░░ ░          ░░   ░  ░░                           ░  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒░▓▒██
███████▓▒▒░░░░░             ░░ ░░░░░░                          ░░░░░░░░    ░░░░░░░░░░░░░░░░░░▒▒▒▒▓▓█
██████▓▓▓▒░░░░░               ░░░░░░░░░░░░    ░░ ░          ░ ░░ ░░░░  ░░░░░░░░░░░░░▒▒▒▒░▒░░░▒▒▓█▓██
███████▓▒▒▒▒▒▒░░ ░░          ░░░░░░░░░░░░░░░░▒▒░▒▒▒▒▒░░░░░ ░░ ░░▒░░   ░░░░░░░░░░░░▒▒▒▒▒░░░░░▒▒▓█████
███████▓▒▒░░▒▒▒░          ░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░▒░░░░░░░░▒▒▒▒▒▒░░▒░░▒▒▓███▓██
██████▓▓▒▒░░▒▒▒▒░         ░░░░░░░░░░░░░░░▒▒░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▒▒▒▒░▒▒▒▒▒▓██████▓██
███████▓▓▒░░▒▒▒░░░░░░  ░ ░░░░░░░░▒░▒▒░░░░▒░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓███████▓██
███████▓▓▒▒▒▒▒░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓██████████
███████▓██▒░▒░░░░░░░░░░░░░░░░░░▒▒░▒▒▒▒░▒▒░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒██████▓▓██
██▓████▓███▒░▒░░░░░░░░░░░░░░░░▒░▒▒▒▒▒░▒▒░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒██████▓███
███████▓▓███▒░░░░░░▒▒░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▓▓██████████
███████▓▓████▒░▒▒░░▒▒░░░▒▒▒░▒▒░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▓▓▓███████████
▓██████▓▓█████▒▒▒▒▒░░░░░▒▒▒▓▒░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░▒░▒▒▒▒▒▒▒░▒▒▒▒▒▒▒▓▓▒▓▓▓▓▓▒░▒▒▒░░▒▓████████▓███
▓██████▓▓█████▒▒▒▒░░░░░░▒▒▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░ ░░▒▒▒▒░▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒░ ░▒▒▓▓▓▒▒▓████████████
▓█████▓▓▓███████▒░░░░░░▒▒▒▓▓▓▓▓░░▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░▒▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▒▒░░░░▒▓▓▓▒▓▓▓████████▓███
▓██████▓▓████████░░░░░░░▒▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░▒▒▓▒▒▒▒░▒▒▒▒▒▒▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓████████████
▓██████▓▓███████▒░░░░░▒░▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓████████▓███
▓▓▓████▓████████▒▒▒░░░░░▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▒▒▒▓▓▓▓▓▓▓████████▓███
▓▓█████▓▓▓█████▓▒▒▒▒▒░░░░▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▒▓▓▓▓▓▓▓▓████████▓███
▓██████▓▓██████▓▒▒▒▒░░░░░▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓████████████
▓██████▓▓██████▒░░░░░░░░▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓████████▓▓███
▓██████▓▓██████▓▒▒░░░░░░▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▓▓▓▓▓▓▓▓▓█████████████
▓▓▓████▓▓▓██████▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▓▓▓▓▓▓▓▓█████████▓████
▓██████▓▓███████▓▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▒▓▓▓▓▓▓██████████▓████
▓▓▓████▓▓████████▓▓▒▒▒▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▒▓▓▓▓▓████████████████
▓▓▓███▓▓▓█████████▓▒▒▒▒▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▒▓██▓██████████▓▓████
▓██████▓▓███████████▓▒▒▒▒▒▒▒░▒░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▓▓███▓██████████▓█████
▓▓▓██▓█▓▓████████████▓▒▒▒▒░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▒▒▒▓████████████████▓█████
▓▓▓██▓█▓▓██████████▒▒░▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓██████████████████▓████
▓▓▓▓█▓▓▓▓██████▓▒▒░░░░▓▒▒░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒░▒▒▒▒▒▒▒▒▒▓▓▒▓▓▓▓▓███████▓▓███████████▓████
▓▓▓█▓▓▓▓▓▓▓▒▒▒▒▒░░░░░░▓▒▒░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒░░▒▒▒▒▒▒▒▒▓▓▓█████████▓███████████▓█████
▓▓▓▓░▒░▒▒▒▒▒░░░░░░░░░▒▓▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░▒▒▒▒▒▒▒▒▒▓▓▓▓██████████▓▓██████████▓█████
▒▒░░░░░░░░░░░░░░░░░░░▒▓▒▒▒░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓██████████▓▓██████████▓████▓
░░░░░░░░░░░░░░░░░░░░░▓▓▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▒▒▓▓██████▓▓█████████▓▓████▓
░░░░░░░░░░░░░░░░░░░░░▓▓▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▓▓▓███████████████▓
░░░░░░░░░░░░░░░▒▒▒▒▒▒▓▓▓▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒░░▒▒▒▒▒▒▒▒▒▒▒▒▓████████▓▓████▓
░░░░░░░░░░░░░░░░░▒▒▒▒▓▓▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▒▒░░░▒▒▒▒▒▒▒▒▒▒▒▒▓██████▓▓████▓
░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▒▓▒░░▒▒░▒░░░▒░▒▒░▒▒▒▒▒▒▒▓█████▓█████▓
░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▒▒▓▓▓▓▒▒░░░▒▒▒▒▒▒░░░░▒▒░▒░░▒▒▒▒▓████▓████▓▓
░░░░░░░░░░░░░░░░░░░▒▒░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒░░▒▒▒▒░░▒░░░░▒▒░░░░░▒▒▒▓███▓▓███▓▓
░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░▒▒░▒▒░░░░░░▒▒░░░░▒▒▒▒███▓████▓▓
░░░░░░░░░░░░░░░░░░▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒░░▒▒▒▒▒▒▒▒░░░░▒▒▒▒▒▒▒▒▒██▓▓████▓▓
░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░▒▒░░▒░░░░░░░▒░░░░▒▒▒▓█▓▓████▓▓
░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒░░░▒▒▒▒▒▒▒▒▒░▒▒▒▒░▒▒▒▒░▓█▓▓████▓▓
░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒░░░▒▒▒▒▒▒░░░░░▒▒▒▒░▒▒░▒▓█▓▓████▓▓
░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▓▓▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░▒▒▒░░▒▒▒░░░░░░░▒▒▒░▒▓█▓▓████▓▓
░░▒░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒░░░░▒▒▒░░▒▒▒░░░░░░▒▒░░▒▓█▓▓████▓▓
░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒░░░░▒▒▒▒░░▒▒░▒░░░░░▒░░▒▓█▓▓███▓▓▓

EOF
fi

# Prompt user for AppID or name
read -rp "Enter the Steam AppID or game name: " input
if [[ "$input" =~ ^[0-9]+$ ]]; then
    APPID="$input"
else
    search_steam "$input"
fi

echo "Selected AppID: $APPID"

echo "===== Cleaning up old depots ====="
rm -rf "$DEPOT_BASE"

echo "===== Running Vapor Depot Downloader for AppID: $APPID ====="

if [[ ! -d "$VENV_DIR" ]]; then
    echo "Error: Virtual environment not found at $VENV_DIR."
    exit 1
fi

"$PYTHON_BIN" "$SCRIPT" "$APPID"

SH_FILE="${APPID}.sh"

if [[ -f "$SH_FILE" ]]; then
    echo "===== Running generated download script: $SH_FILE ====="
    bash "$SH_FILE"
    echo "===== Download complete, cleaning up temporary files ====="
    rm -f "$SH_FILE"
    rm -f *.manifest *.key *.lua
    echo "===== Cleanup complete ====="
else
    echo "Error: Generated script $SH_FILE not found."
    exit 1
fi

# Flatten depots
TOP_FOLDER=$(find "$DEPOT_BASE" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | head -n 1)
if [[ -z "$TOP_FOLDER" ]]; then
    echo "No folders found in $DEPOT_BASE"
    exit 1
fi

echo "===== Flattening nested subfolders inside $TOP_FOLDER ====="
shopt -s dotglob
for SUB in "$TOP_FOLDER"/*/; do
    [[ -d "$SUB" ]] || continue
    echo "Moving contents of $SUB to $TOP_FOLDER"
    mv -f "$SUB"* "$TOP_FOLDER/"
    rmdir "$SUB"
done
shopt -u dotglob

# Fetch official name
API_URL="https://store.steampowered.com/api/appdetails?appids=$APPID"
OFFICIAL_NAME=$(curl -s "$API_URL" | jq -r ".[\"$APPID\"].data.name // \"Game_$APPID\"")
[[ -z "$OFFICIAL_NAME" || "$OFFICIAL_NAME" == "null" ]] && OFFICIAL_NAME="Game_$APPID"
INSTALL_DIR_NAME=$(echo "$OFFICIAL_NAME" | tr '/:?*"<>|' '_')

# Rename top folder
FINAL_FOLDER="$DEPOT_BASE/$INSTALL_DIR_NAME"
mv "$TOP_FOLDER" "$FINAL_FOLDER"
echo "===== Top folder renamed to $INSTALL_DIR_NAME ====="

# Detect Steam libraries
STEAM_ROOT="$HOME/.local/share/Steam"
LIBRARY_PATHS=("$STEAM_ROOT/steamapps")
if [[ -f "$STEAM_ROOT/steamapps/libraryfolders.vdf" ]]; then
    while IFS= read -r line; do
        if [[ $line =~ \"path\"[[:space:]]+\"([^\"]+)\" ]]; then
            LIBRARY_PATHS+=("${BASH_REMATCH[1]}/steamapps")
        fi
    done < <(grep '"path"' "$STEAM_ROOT/steamapps/libraryfolders.vdf")
fi

mapfile -t LIBRARY_PATHS < <(printf '%s\n' "${LIBRARY_PATHS[@]}" | awk '!seen[$0]++')

# Choose library
if [[ ${#LIBRARY_PATHS[@]} -eq 1 ]]; then
    STEAM_LIB="${LIBRARY_PATHS[0]}"
else
    echo "Select Steam library:"
    select LIB in "${LIBRARY_PATHS[@]}"; do
        if [[ -n "$LIB" ]]; then
            STEAM_LIB="$LIB"
            break
        fi
    done
fi

INSTALL_DIR="$STEAM_LIB/common/$INSTALL_DIR_NAME"
mkdir -p "$INSTALL_DIR"

echo "===== Moving game files to Steam library folder ====="
cp -r "$FINAL_FOLDER/"* "$INSTALL_DIR/"

# Generate appmanifest
ACF_FILE="$STEAM_LIB/appmanifest_$APPID.acf"
cat > "$ACF_FILE" <<EOF
"AppState"
{
    "AppID" "$APPID"
    "Universe" "1"
    "name" "$OFFICIAL_NAME"
    "StateFlags" "1026"
    "installdir" "$INSTALL_DIR_NAME"
    "LastUpdated" "$(date +%s)"
    "SizeOnDisk" "0"
    "buildid" "0"
    "CompatTool" ""
    "CompatToolOverride" ""
}
EOF

echo "===== Game added to Steam library successfully! ====="
echo "Install folder: $INSTALL_DIR"

echo "Press Enter to exit..."
read -r
▓██████▓▓█████▒▒▒▒░░░░░░▒▒▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░ ░░▒▒▒▒░▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒░ ░▒▒▓▓▓▒▒▓████████████
▓█████▓▓▓███████▒░░░░░░▒▒▒▓▓▓▓▓░░▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░▒▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▒▒░░░░▒▓▓▓▒▓▓▓████████▓███
▓██████▓▓████████░░░░░░░▒▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░▒▒▓▒▒▒▒░▒▒▒▒▒▒▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓████████████
▓██████▓▓███████▒░░░░░▒░▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓████████▓███
▓▓▓████▓████████▒▒▒░░░░░▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▒▒▒▓▓▓▓▓▓▓████████▓███
▓▓█████▓▓▓█████▓▒▒▒▒▒░░░░▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▒▓▓▓▓▓▓▓▓████████▓███
▓██████▓▓██████▓▒▒▒▒░░░░░▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓████████████
▓██████▓▓██████▒░░░░░░░░▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓████████▓▓███
▓██████▓▓██████▓▒▒░░░░░░▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▓▓▓▓▓▓▓▓▓█████████████
▓▓▓████▓▓▓██████▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▓▓▓▓▓▓▓▓█████████▓████
▓██████▓▓███████▓▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▒▓▓▓▓▓▓██████████▓████
▓▓▓████▓▓████████▓▓▒▒▒▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▒▓▓▓▓▓████████████████
▓▓▓███▓▓▓█████████▓▒▒▒▒▒▒▒▒▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▒▓██▓██████████▓▓████
▓██████▓▓███████████▓▒▒▒▒▒▒▒░▒░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▒▒▒▓▓███▓██████████▓█████
▓▓▓██▓█▓▓████████████▓▒▒▒▒░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▒▒▒▓████████████████▓█████
▓▓▓██▓█▓▓██████████▒▒░▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓██████████████████▓████
▓▓▓▓█▓▓▓▓██████▓▒▒░░░░▓▒▒░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒░▒▒▒▒▒▒▒▒▒▓▓▒▓▓▓▓▓███████▓▓███████████▓████
▓▓▓█▓▓▓▓▓▓▓▒▒▒▒▒░░░░░░▓▒▒░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒░░▒▒▒▒▒▒▒▒▓▓▓█████████▓███████████▓█████
▓▓▓▓░▒░▒▒▒▒▒░░░░░░░░░▒▓▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░▒▒▒▒▒▒▒▒▒▓▓▓▓██████████▓▓██████████▓█████
▒▒░░░░░░░░░░░░░░░░░░░▒▓▒▒▒░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓██████████▓▓██████████▓████▓
░░░░░░░░░░░░░░░░░░░░░▓▓▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▒▒▓▓██████▓▓█████████▓▓████▓
░░░░░░░░░░░░░░░░░░░░░▓▓▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▓▓▓███████████████▓
░░░░░░░░░░░░░░░▒▒▒▒▒▒▓▓▓▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒░░▒▒▒▒▒▒▒▒▒▒▒▒▓████████▓▓████▓
░░░░░░░░░░░░░░░░░▒▒▒▒▓▓▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▒▒░░░▒▒▒▒▒▒▒▒▒▒▒▒▓██████▓▓████▓
░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▒▓▒░░▒▒░▒░░░▒░▒▒░▒▒▒▒▒▒▒▓█████▓█████▓
░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▒▒▓▓▓▓▒▒░░░▒▒▒▒▒▒░░░░▒▒░▒░░▒▒▒▒▓████▓████▓▓
░░░░░░░░░░░░░░░░░░░▒▒░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒░░▒▒▒▒░░▒░░░░▒▒░░░░░▒▒▒▓███▓▓███▓▓
░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░▒▒░▒▒░░░░░░▒▒░░░░▒▒▒▒███▓████▓▓
░░░░░░░░░░░░░░░░░░▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒░░▒▒▒▒▒▒▒▒░░░░▒▒▒▒▒▒▒▒▒██▓▓████▓▓
░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░▒▒░░▒░░░░░░░▒░░░░▒▒▒▓█▓▓████▓▓
░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒░░░▒▒▒▒▒▒▒▒▒░▒▒▒▒░▒▒▒▒░▓█▓▓████▓▓
░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒░░░▒▒▒▒▒▒░░░░░▒▒▒▒░▒▒░▒▓█▓▓████▓▓
░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▓▓▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░▒▒▒░░▒▒▒░░░░░░░▒▒▒░▒▓█▓▓████▓▓
░░▒░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒░░░░▒▒▒░░▒▒▒░░░░░░▒▒░░▒▓█▓▓████▓▓
░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒░░░░▒▒▒▒░░▒▒░▒░░░░░▒░░▒▓█▓▓███▓▓▓

EOF

# Prompt user for AppID or name
read -rp "Enter the Steam AppID or game name: " input
if [[ "$input" =~ ^[0-9]+$ ]]; then
    APPID="$input"
else
    search_steam "$input"
fi

echo "Selected AppID: $APPID"

echo "===== Cleaning up old depots ====="
rm -rf "$DEPOT_BASE"

echo "===== Running Vapor Depot Downloader for AppID: $APPID ====="

# Setup venv if it doesn't exist
if [[ ! -d "$VENV_DIR" ]]; then
    echo "Virtual environment not found, running setup..."
    if [[ -f "$VAPOR_DIR/setup.sh" ]]; then
        bash "$VAPOR_DIR/setup.sh"
    else
        echo "Error: setup.sh not found!"
        exit 1
    fi
fi

"$PYTHON_BIN" "$SCRIPT" "$APPID"

SH_FILE="${APPID}.sh"

if [[ -f "$SH_FILE" ]]; then
    echo "===== Running generated download script: $SH_FILE ====="
    bash "$SH_FILE"
    echo "===== Download complete, cleaning up temporary files ====="
    rm -f "$SH_FILE"
    rm -f *.manifest *.key *.lua
    echo "===== Cleanup complete ====="
else
    echo "Error: Generated script $SH_FILE not found."
    exit 1
fi

# Flatten depots
TOP_FOLDER=$(find "$DEPOT_BASE" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | head -n 1)
if [[ -z "$TOP_FOLDER" ]]; then
    echo "No folders found in $DEPOT_BASE"
    exit 1
fi

echo "===== Flattening nested subfolders inside $TOP_FOLDER ====="
shopt -s dotglob
for SUB in "$TOP_FOLDER"/*/; do
    [[ -d "$SUB" ]] || continue
    echo "Moving contents of $SUB to $TOP_FOLDER"
    mv -f "$SUB"* "$TOP_FOLDER/"
    rmdir "$SUB"
done
shopt -u dotglob

# Fetch official name
API_URL="https://store.steampowered.com/api/appdetails?appids=$APPID"
OFFICIAL_NAME=$(curl -s "$API_URL" | jq -r ".[\"$APPID\"].data.name // \"Game_$APPID\"")
[[ -z "$OFFICIAL_NAME" || "$OFFICIAL_NAME" == "null" ]] && OFFICIAL_NAME="Game_$APPID"
INSTALL_DIR_NAME=$(echo "$OFFICIAL_NAME" | tr '/:?*"<>|' '_')

# Rename top folder
FINAL_FOLDER="$DEPOT_BASE/$INSTALL_DIR_NAME"
mv "$TOP_FOLDER" "$FINAL_FOLDER"
echo "===== Top folder renamed to $INSTALL_DIR_NAME ====="

# Detect Steam libraries
STEAM_ROOT="$HOME/.local/share/Steam"
LIBRARY_PATHS=("$STEAM_ROOT/steamapps")
if [[ -f "$STEAM_ROOT/steamapps/libraryfolders.vdf" ]]; then
    while IFS= read -r line; do
        if [[ $line =~ \"path\"[[:space:]]+\"([^\"]+)\" ]]; then
            LIBRARY_PATHS+=("${BASH_REMATCH[1]}/steamapps")
        fi
    done < <(grep '"path"' "$STEAM_ROOT/steamapps/libraryfolders.vdf")
fi

mapfile -t LIBRARY_PATHS < <(printf '%s\n' "${LIBRARY_PATHS[@]}" | awk '!seen[$0]++')

# Choose library
if [[ ${#LIBRARY_PATHS[@]} -eq 1 ]]; then
    STEAM_LIB="${LIBRARY_PATHS[0]}"
else
    echo "Select Steam library:"
    select LIB in "${LIBRARY_PATHS[@]}"; do
        if [[ -n "$LIB" ]]; then
            STEAM_LIB="$LIB"
            break
        fi
    done
fi

INSTALL_DIR="$STEAM_LIB/common/$INSTALL_DIR_NAME"
mkdir -p "$INSTALL_DIR"

echo "===== Moving game files to Steam library folder ====="
cp -r "$FINAL_FOLDER/"* "$INSTALL_DIR/"

# Generate appmanifest
ACF_FILE="$STEAM_LIB/appmanifest_$APPID.acf"
cat > "$ACF_FILE" <<EOF
"AppState"
{
    "AppID" "$APPID"
    "Universe" "1"
    "name" "$OFFICIAL_NAME"
    "StateFlags" "1026"
    "installdir" "$INSTALL_DIR_NAME"
    "LastUpdated" "$(date +%s)"
    "SizeOnDisk" "0"
    "buildid" "0"
    "CompatTool" ""
    "CompatToolOverride" ""
}
EOF

echo "===== Game added to Steam library successfully! ====="
echo "Install folder: $INSTALL_DIR"

echo "Press Enter to exit..."
read -r
