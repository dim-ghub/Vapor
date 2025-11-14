#!/usr/bin/env bash
set -e

# Function to print text column by column
type_column_by_column() {
    local text="$1"
    local delay="${2:-0.01}"
    local IFS=$'\n'
    for line in $text; do
        local len=${#line}
        for ((i=0; i<len; i++)); do
            printf "%s" "${line:i:1}"
            sleep "$delay"
        done
        printf "\n"
    done
}

# First huge banner
mpv --no-video --really-quiet --no-terminal ~/.local/share/Vapor/assets/1.mp3 &
sleep 0.5
cat <<'EOF'
 █     █░▓█████  ██▓     ▄████▄   ▒█████   ███▄ ▄███▓▓█████ 
▓█░ █ ░█░▓█   ▀ ▓██▒    ▒██▀ ▀█  ▒██▒  ██▒▓██▒▀█▀ ██▒▓█   ▀ 
▒█░ █ ░█ ▒███   ▒██░    ▒▓█    ▄ ▒██░  ██▒▓██    ▓██░▒███   
░█░ █ ░█ ▒▓█  ▄ ▒██░    ▒▓▓▄ ▄██▒▒██   ██░▒██    ▒██ ▒▓█  ▄ 
░░██▒██▓ ░▒████▒░██████▒▒ ▓███▀ ░░ ████▓▒░▒██▒   ░██▒░▒████▒
░ ▓░▒ ▒  ░░ ▒░ ░░ ▒░▓  ░░ ░▒ ▒  ░░ ▒░▒░▒░ ░ ▒░   ░  ░░░ ▒░ ░
  ▒ ░ ░   ░ ░  ░░ ░ ▒  ░  ░  ▒     ░ ▒ ▒░ ░  ░      ░ ░ ░  ░
  ░   ░     ░     ░ ░   ░        ░ ░ ░ ▒  ░      ░      ░   
    ░       ░  ░    ░  ░░ ░          ░ ░         ░      ░  ░
                        ░                                   
EOF

sleep 1.5
clear

# Second smaller banner
mpv --no-video --really-quiet --no-terminal ~/.local/share/Vapor/assets/1.mp3 &
sleep 0.5
cat <<'EOF'
▄▄▄█████▓ ▒█████  
▓  ██▒ ▓▒▒██▒  ██▒
▒ ▓██░ ▒░▒██░  ██▒
░ ▓██▓ ░ ▒██   ██░
  ▒██▒ ░ ░ ████▓▒░
  ▒ ░░   ░ ▒░▒░▒░ 
    ░      ░ ▒ ▒░ 
  ░      ░ ░ ░ ▒  
             ░ ░  
EOF

sleep 1.5
clear

# Final banner (typed column by column)
FINAL_BANNER='░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓███████▓▒░  
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
 ░▒▓█▓▒▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
 ░▒▓█▓▒▒▓█▓▒░░▒▓████████▓▒░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░  
  ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
  ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
   ░▒▓██▓▒░  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░       ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░ 
                                                                   '

mpv --no-video --really-quiet --no-terminal ~/.local/share/Vapor/assets/2.mp3 &
type_column_by_column "$FINAL_BANNER" 0.002

echo
echo "================ Menu ================"

MODULES_DIR="$HOME/.local/share/Vapor/modules"
mapfile -t MODULES < <(find "$MODULES_DIR" -maxdepth 1 -type f -name "*.sh" | sort)

if [[ ${#MODULES[@]} -eq 0 ]]; then
    echo "No modules found in $MODULES_DIR"
    exit 1
fi

for i in "${!MODULES[@]}"; do
    script_name=$(basename "${MODULES[i]}" .sh)
    echo "$((i+1))) $script_name"
done
echo "======================================"

read -rp "Select an option: " opt

if ! [[ "$opt" =~ ^[0-9]+$ ]] || ((opt < 1 || opt > ${#MODULES[@]})); then
    echo "Invalid option"
    exit 1
fi

SELECTED_MODULE="${MODULES[opt-1]}"
echo "Running $(basename "$SELECTED_MODULE")..."
bash "$SELECTED_MODULE"

echo
read -rp "Press Enter to exit..."
