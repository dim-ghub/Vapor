#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/SLSsteam/config.yaml"
LIBRARYVDF="$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
DEFAULT_LIB="$HOME/.local/share/Steam/steamapps"

echo "Reading Steam library folders from: $LIBRARYVDF"

STEAM_LIBS=()

[[ -d "$DEFAULT_LIB" ]] && STEAM_LIBS+=("$DEFAULT_LIB")

if [[ -f "$LIBRARYVDF" ]]; then
    while IFS= read -r line; do
        if [[ $line =~ \"path\"[[:space:]]*\"([^\"]+)\" ]]; then
            path="${BASH_REMATCH[1]}/steamapps"
            [[ -d "$path" ]] && STEAM_LIBS+=("$path")
        fi
    done < "$LIBRARYVDF"
fi

mapfile -t STEAM_LIBS < <(printf "%s\n" "${STEAM_LIBS[@]}" | awk '!seen[$0]++')

echo "Detected Steam libraries:"
printf " - %s\n" "${STEAM_LIBS[@]}"
echo ""

declare -A GAME_MAP

for lib in "${STEAM_LIBS[@]}"; do
    shopt -s nullglob
    for acf in "$lib"/appmanifest_*.acf; do
        [[ -f "$acf" ]] || continue
        appid=$(basename "$acf" | grep -o '[0-9]\+')
        installdir=$(grep -m1 '"installdir"' "$acf" | sed -E 's/.*"installdir"[[:space:]]*"([^"]+)".*/\1/')
        [[ -z "$installdir" ]] && installdir="App_$appid"
        [[ -z "${GAME_MAP[$installdir]+x}" ]] && GAME_MAP["$installdir"]="$appid"
    done
    shopt -u nullglob
done

if [[ ${#GAME_MAP[@]} -eq 0 ]]; then
    echo "No installed games found."
    exit 1
fi

GAME_LIST=("${!GAME_MAP[@]}")
echo "Select a game to add to FakeAppIds:"

if command -v fzf >/dev/null 2>&1; then
    CHOICE=$(printf "%s\n" "${GAME_LIST[@]}" | fzf --height=20 --reverse --prompt="Game: ")
    [[ -z "$CHOICE" ]] && { echo "No selection"; exit 1; }
else
    i=1
    for g in "${GAME_LIST[@]}"; do
        printf "%3d) %s\n" "$i" "$g"
        ((i++))
    done
    read -rp "Choose number: " num
    if ! [[ $num =~ ^[0-9]+$ ]] || (( num < 1 || num > ${#GAME_LIST[@]} )); then
        echo "Invalid selection."
        exit 1
    fi
    CHOICE="${GAME_LIST[$((num-1))]}"
fi

APPID="${GAME_MAP[$CHOICE]}"
echo ""
echo "Selected: $CHOICE (AppID: $APPID)"
echo ""

mkdir -p "$(dirname "$CONFIG_FILE")"
[[ -f "$CONFIG_FILE" ]] || echo "FakeAppIds:" > "$CONFIG_FILE"

if ! grep -qE '^\s*FakeAppIds:' "$CONFIG_FILE"; then
    echo -e "\nFakeAppIds:" >> "$CONFIG_FILE"
fi

if grep -qE "^[[:space:]]*$APPID:[[:space:]]*480[[:space:]]*$" "$CONFIG_FILE"; then
    echo "Mapping already exists. Nothing to do."
    exit 0
fi

LINE_NUM=$(grep -n '^\s*FakeAppIds:' "$CONFIG_FILE" | cut -d: -f1)

if [[ -n "$LINE_NUM" ]]; then
    sed -i "$((LINE_NUM+1))i \  $APPID: 480" "$CONFIG_FILE"
else
    echo "  $APPID: 480" >> "$CONFIG_FILE"
fi

echo "Added mapping under FakeAppIds:"
echo "  $APPID: 480"
