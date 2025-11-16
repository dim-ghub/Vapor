#!/usr/bin/env bash
set -e
clear

# -------------------------------
# Find Steam libraries
# -------------------------------
STEAM_LIBS=("$HOME/.local/share/Steam/steamapps")
if [[ -f "$HOME/.local/share/Steam/config/config.vdf" ]]; then
    while read -r line; do
        if [[ "$line" =~ \"Path\"\ *\"(.+)\" ]]; then
            STEAM_LIBS+=("${BASH_REMATCH[1]}/steamapps")
        fi
    done < <(grep '"Path"' "$HOME/.local/share/Steam/config/config.vdf")
fi

# -------------------------------
# Detect installed games
# -------------------------------
declare -A GAMES_PATH
declare -A GAME_APPID
declare -a GAME_NAMES

for LIB in "${STEAM_LIBS[@]}"; do
    COMMON_DIR="$LIB/common"
    [[ -d "$COMMON_DIR" ]] || continue

    for ACF in "$LIB"/appmanifest_*.acf; do
        [[ -f "$ACF" ]] || continue
        APPID=$(basename "$ACF" | sed -E 's/appmanifest_([0-9]+)\.acf/\1/')
        INSTALLDIR=$(grep '"installdir"' "$ACF" | head -n1 | sed -E 's/.*"\s*installdir\s*"\s*"(.+)"/\1/')
        [[ -z "$INSTALLDIR" ]] && continue
        GAME_DIR="$COMMON_DIR/$INSTALLDIR"
        [[ -d "$GAME_DIR" ]] || continue

        GAMES_PATH["$INSTALLDIR"]="$GAME_DIR"
        GAME_APPID["$INSTALLDIR"]="$APPID"
        GAME_NAMES+=("$INSTALLDIR")
    done
done

if [[ ${#GAME_NAMES[@]} -eq 0 ]]; then
    echo "No installed Steam games found."
    exit 1
fi

# -------------------------------
# Display installed games
# -------------------------------
IFS=$'\n' SORTED_GAMES=($(sort <<<"${GAME_NAMES[*]}"))
unset IFS

declare -a APPIDS
declare -a DISPLAY_NAMES

echo "Installed games:"
i=1
for FOLDER_NAME in "${SORTED_GAMES[@]}"; do
    APPID="${GAME_APPID[$FOLDER_NAME]}"
    echo "$i) $FOLDER_NAME"
    DISPLAY_NAMES[i-1]="$FOLDER_NAME"
    APPIDS[i-1]="$APPID"
    ((i++))
done

read -rp "Select a game by number: " opt
if ! [[ "$opt" =~ ^[0-9]+$ ]] || ((opt < 1 || opt > ${#APPIDS[@]})); then
    echo "Invalid selection"
    exit 1
fi

SELECTED_APPID="${APPIDS[opt-1]}"
GAME_NAME="${DISPLAY_NAMES[opt-1]}"
GAME_DIR="${GAMES_PATH[$GAME_NAME]}"

echo "Selected: $GAME_NAME → $GAME_DIR"

# -------------------------------
# Download & apply fix zips
# -------------------------------
TMP_DIR=$(mktemp -d)
echo "Temporary extraction folder: $TMP_DIR"

FIX_URLS=(
    "https://github.com/ShayneVi/OnlineFix1/releases/download/fixes/${SELECTED_APPID}.zip"
    "https://github.com/ShayneVi/OnlineFix2/releases/download/fixes/${SELECTED_APPID}.zip"
    "https://github.com/ShayneVi/Bypasses/releases/download/v1.0/${SELECTED_APPID}.zip"
)

for URL in "${FIX_URLS[@]}"; do
    echo "Checking: $URL"
    if curl --head --silent --fail "$URL" >/dev/null; then
        echo "Downloading $URL..."
        TMP_ZIP="$TMP_DIR/temp.zip"
        curl -L -o "$TMP_ZIP" "$URL"

        echo "Extracting $URL..."
        7z x "$TMP_ZIP" -o"$TMP_DIR" -y >/dev/null
        rm "$TMP_ZIP"

        TOP_LEVEL_ITEMS=("$TMP_DIR"/*)
        if [[ ${#TOP_LEVEL_ITEMS[@]} -eq 1 && -d "${TOP_LEVEL_ITEMS[0]}" ]]; then
            rsync -a "${TOP_LEVEL_ITEMS[0]}/" "$GAME_DIR"/
        else
            for item in "${TOP_LEVEL_ITEMS[@]}"; do
                if [[ -d "$item" ]]; then
                    rsync -a "$item"/ "$GAME_DIR"/
                else
                    cp -a "$item" "$GAME_DIR"/
                fi
            done
        fi

        rm -rf "$TMP_DIR"/*
        echo "Files from this zip added to game directory."
    else
        echo "Not found, skipping."
    fi
done

rmdir "$TMP_DIR"

echo "All OnlineFix files applied to: $GAME_DIR"
echo
echo "Applying permanent Wine DLL overrides…"

# --------------------------------------------------------
# apply DLL overrides to prefix
# --------------------------------------------------------

PROTON_PREFIX="$HOME/.local/share/Steam/steamapps/compatdata/$SELECTED_APPID/pfx"

if [[ -d "$PROTON_PREFIX" ]]; then
    WINEPREFIX="$PROTON_PREFIX"
    echo "Detected Proton prefix: $WINEPREFIX"
else
    echo "ERROR: No Proton prefix found for this game:"
    echo "  $PROTON_PREFIX"
    echo
    echo "Cannot apply DLL overrides."
    exit 1
fi

export WINEPREFIX
echo "Using prefix: $WINEPREFIX"

declare -A DLLS=(
    ["OnlineFix64"]="n"
    ["SteamOverlay64"]="n"
    ["winmm"]="n,b"
    ["dnet"]="n"
    ["steam_api64"]="n"
    ["winhttp"]="n,b"
)

for DLL in "${!DLLS[@]}"; do
    VALUE="${DLLS[$DLL]}"
    echo " → Setting $DLL = $VALUE"
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "$DLL" /d "$VALUE" /f >/dev/null
done

echo
echo "=============================================================="
echo "DLL overrides applied inside the Wine prefix:"
echo "$WINEPREFIX"
echo "=============================================================="
echo "Done."
