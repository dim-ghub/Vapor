#!/usr/bin/env bash
set -e
clear

CONFIG_DIR="$HOME/.local/share/Vapor"
CONFIG_FILE="$CONFIG_DIR/vapor-conf.json"

# ------------------------------------------------------------
# CONFIG HANDLING
# ------------------------------------------------------------
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        mkdir -p "$CONFIG_DIR"
        cat > "$CONFIG_FILE" <<EOF
{
    "skip_intro": false,
    "nosound": false
}
EOF
    fi

    SKIP_INTRO_CFG=$(jq -r '.skip_intro' "$CONFIG_FILE")
    NOSOUND_CFG=$(jq -r '.nosound' "$CONFIG_FILE")

    # Convert true/false → 1/0
    [[ "$SKIP_INTRO_CFG" == "true" ]] && SKIP_INTRO=1 || SKIP_INTRO=0
    [[ "$NOSOUND_CFG" == "true" ]] && NOSOUND=1 || NOSOUND=0
}

# Load initial config
load_config

# ------------------------------------------------------------
# FLAG HANDLING — FLAGS OVERRIDE CONFIG BUT DO NOT SAVE
# ------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --skip-intro) SKIP_INTRO=1 ;;   # override only
        --nosound) NOSOUND=1 ;;         # override only
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# ------------------------------------------------------------
# SOUND / TEXT FUNCTIONS
# ------------------------------------------------------------
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

play_select_sound() {
    [[ $NOSOUND -eq 1 ]] && return
    mpv --no-video --quiet --no-terminal ~/.local/share/Vapor/assets/select.mp3 &
}

start_theme_loop() {
    [[ $NOSOUND -eq 1 ]] && return
    while true; do
        mpv --no-video --quiet --no-terminal ~/.local/share/Vapor/assets/theme.mp3
    done &
    THEME_PID=$!
}

stop_theme_loop() {
    [[ $NOSOUND -eq 1 ]] && return
    if [[ -n "$THEME_PID" ]]; then
        kill "$THEME_PID" 2>/dev/null || true
    fi
}

# ------------------------------------------------------------
# BANNERS
# ------------------------------------------------------------
if [[ $SKIP_INTRO -ne 1 ]]; then
    [[ $NOSOUND -ne 1 ]] && mpv --no-video --really-quiet --no-terminal ~/.local/share/Vapor/assets/1.mp3 &
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

    [[ $NOSOUND -ne 1 ]] && mpv --no-video --really-quiet --no-terminal ~/.local/share/Vapor/assets/1.mp3 &
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

    FINAL_BANNER='
░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓███████▓▒░  
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
 ░▒▓█▓▒▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
 ░▒▓█▓▒▒▓█▓▒░░▒▓████████▓▒░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░  
  ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
  ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
   ░▒▓██▓▒░  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░       ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░ '
    [[ $NOSOUND -ne 1 ]] && mpv --no-video --really-quiet --no-terminal ~/.local/share/Vapor/assets/2.mp3 &
    type_column_by_column "$FINAL_BANNER" 0.002
fi

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
play_select_sound

if ! [[ "$opt" =~ ^[0-9]+$ ]] || ((opt < 1 || opt > ${#MODULES[@]})); then
    echo "Invalid option"
    exit 1
fi

SELECTED_MODULE="${MODULES[opt-1]}"
MODULE_NAME=$(basename "$SELECTED_MODULE")

echo "Running $MODULE_NAME..."

if [[ "$MODULE_NAME" == "Download a game.sh" ]]; then
    start_theme_loop
fi

bash "$SELECTED_MODULE"
stop_theme_loop

echo
read -rp "Press Enter to exit..."
