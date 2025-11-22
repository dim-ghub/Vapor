#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/.local/share/Vapor"
mkdir -p "$BASE_DIR"

get_steam_libraries() {
    local STEAM_ROOT="$HOME/.local/share/Steam"
    local libs=("$STEAM_ROOT/steamapps")
    if [[ -f "$STEAM_ROOT/steamapps/libraryfolders.vdf" ]]; then
        while IFS= read -r line; do
            if [[ $line =~ \"path\"[[:space:]]+\"([^\"]+)\" ]]; then
                libs+=("${BASH_REMATCH[1]}/steamapps")
            fi
        done < <(grep '"path"' "$STEAM_ROOT/steamapps/libraryfolders.vdf")
    fi
    printf "%s\n" "${libs[@]}"
}

libraries=($(get_steam_libraries))
games=()
for lib in "${libraries[@]}"; do
    for mf in "$lib"/appmanifest_*.acf; do
        [[ -f "$mf" ]] || continue
        appid=$(grep '"appid"' "$mf" | grep -oE '[0-9]+')
        name=$(grep '"name"' "$mf" | head -n1 | sed -E 's/.*"name"[[:space:]]+"([^"]+)".*/\1/')
        [[ -n "$appid" && -n "$name" ]] && games+=("$appid::$name")
    done
done

if [[ ${#games[@]} -eq 0 ]]; then
    echo "No installed Steam games found."
    exit 1
fi

echo "Select a game to patch:"
for i in "${!games[@]}"; do
    echo "$((i+1))) ${games[i]##*::}"
done
read -rp "Choice: " choice
[[ "$choice" =~ ^[0-9]+$ ]] || exit 1
((choice--))
[[ $choice -lt 0 || $choice -ge ${#games[@]} ]] && exit 1
selection="${games[choice]##*::}"
selected_appid="${games[choice]%%::*}"

game_dir=""
for lib in "${libraries[@]}"; do
    for d in "$lib"/common/*; do
        [[ -d "$d" ]] || continue
        if [[ "$(basename "$d")" == "$selection" ]]; then
            game_dir="$d"
            break 2
        fi
    done
done

if [[ -z "$game_dir" ]]; then
    echo "Could not find game folder for '$selection'"
    exit 1
fi

cd "$BASE_DIR" || exit 1

steamless_url_encoded="aHR0cHM6Ly9naXRodWIuY29tL2F0b20wcy9TdGVhbWxlc3MvcmVsZWFzZXMvZG93bmxvYWQvdjMuMS4wLjUvU3RlYW1sZXNzLnYzLjEuMC41Li0uYnkuYXRvbTBzLnppcA=="
steamless_url=$(echo "$steamless_url_encoded" | base64 --decode)

echo "Downloading Steamless..."
curl -fL --retry 3 --retry-delay 2 -o steamless.zip "$steamless_url"

rm -rf steamless
mkdir -p steamless
unzip -o steamless.zip -d steamless > /dev/null
rm -f steamless.zip

if [[ ! -f steamless/Steamless.CLI.exe ]]; then
    echo "Steamless.CLI.exe not found after extraction"
    exit 1
fi

mapfile -t exe_list < <(find "$game_dir" -type f -iname "*.exe")
if [[ ${#exe_list[@]} -eq 0 ]]; then
    echo "No .exe files found in game folder."
    exit 1
fi

echo "Available EXE files:"
for i in "${!exe_list[@]}"; do
    echo "$((i+1))) ${exe_list[i]}"
done
read -rp "Choose an EXE to patch: " exe_index
[[ "$exe_index" =~ ^[0-9]+$ ]] || exit 1
((exe_index--))
exe_choice="${exe_list[exe_index]}"

echo "Patching '$exe_choice'..."
WINEDEBUG=-all wine "$BASE_DIR/steamless/Steamless.CLI.exe" "$exe_choice"

if [[ -f "$exe_choice.unpacked.exe" ]]; then
    mv "$exe_choice" "$exe_choice.bak"
    mv "$exe_choice.unpacked.exe" "$exe_choice"
    echo "Executable unpacked and patched successfully!"
else
    echo "Unpacking failed. No output file created."
    exit 1
fi

cd "$HOME" || exit 1
rm -rf "$BASE_DIR"
