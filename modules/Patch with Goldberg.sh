#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/.local/share/Vapor"
mkdir -p "$BASE_DIR"

# Helper: get Steam libraries
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

# Download Goldberg emulator
goldberg_url_encoded="aHR0cHM6Ly9naXRsYWIuY29tL01yX0dvbGRiZXJnL2dvbGRiZXJnX2VtdWxhdG9yLy0vam9icy80MjQ3ODExMzEwL2FydGlmYWN0cy9kb3dubG9hZA=="
goldberg_url=$(echo "$goldberg_url_encoded" | base64 --decode)
goldberg_zip="$BASE_DIR/Goldberg.zip"
goldberg_dir="$BASE_DIR/Goldberg"
find_interfaces_script="$goldberg_dir/linux/tools/find_interfaces.sh"

rm -rf "$goldberg_dir"
mkdir -p "$goldberg_dir"

echo "Downloading Goldberg emulator..."
curl -L -o "$goldberg_zip" "$goldberg_url"

echo "Extracting Goldberg..."
unzip -q "$goldberg_zip" -d "$goldberg_dir"
rm -f "$goldberg_zip"

# Detect installed Steam games
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

# User selects game
echo "Select a game to patch with Goldberg:"
for i in "${!games[@]}"; do
    echo "$((i+1))) ${games[i]##*::}"
done
read -rp "Choice: " choice
[[ "$choice" =~ ^[0-9]+$ ]] || exit 1
((choice--))
[[ $choice -lt 0 || $choice -ge ${#games[@]} ]] && exit 1
selection="${games[choice]##*::}"
selected_appid="${games[choice]%%::*}"

# Find game directory
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

# Find Steam API DLL
dll_file=$(find "$game_dir" -type f \( -iname "steam_api.dll" -o -iname "steam_api64.dll" \) | head -n 1)
if [[ -z "$dll_file" ]]; then
    echo "No Steam API DLL file found inside game directory."
    exit 1
fi

# Optional: run find_interfaces.sh if exists
if [[ -x "$find_interfaces_script" ]]; then
    sh "$find_interfaces_script" "$dll_file" > "$(dirname "$dll_file")/steam_interfaces.txt"
else
    echo "Warning: find_interfaces.sh not found or not executable."
fi

# Backup and patch DLL
cp -f "$dll_file" "$dll_file.bak"
cp -f "$goldberg_dir/$(basename "$dll_file")" "$dll_file"

# Ensure AppID exists
if [[ -z "$selected_appid" ]]; then
    read -rp "AppID not found automatically. Enter AppID for '$selection': " selected_appid
    if [[ -z "$selected_appid" ]]; then
        echo "No AppID provided. Aborting."
        exit 1
    fi
fi

echo "$selected_appid" > "$(dirname "$dll_file")/steam_appid.txt"

echo "Goldberg emulator patched '$selection' successfully."

# Optional: Setup Steam Metadata Editor (SME)
sme_dir="$BASE_DIR/SME"
repo_url="https://github.com/tralph3/Steam-Metadata-Editor.git"
rm -rf "$sme_dir"
echo "Cloning Steam Metadata Editor (SME)..."
git clone "$repo_url" "$sme_dir"

# Clean unnecessary files
find "$sme_dir" -mindepth 1 -maxdepth 1 ! -name src -exec rm -rf {} +
mv "$sme_dir/src/"* "$sme_dir/"
rm -rf "$sme_dir/src"

echo "SME setup complete at $sme_dir"

# Cleanup
cd "$HOME" || exit 1
# rm -rf "$BASE_DIR"  # optionally keep for debugging
