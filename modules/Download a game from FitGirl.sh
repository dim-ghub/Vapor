#!/usr/bin/env bash
set -euo pipefail

read -rp "Enter game name to search FitGirl: " keyword
[[ -z "${keyword// /}" ]] && { echo "Empty keyword."; exit 1; }

encoded=$(printf "%s" "$keyword" | jq -Rr @uri)

echo "Searching FitGirl for: $keyword"
echo

titles=()
urls=()

while IFS= read -r block; do
    title=$(echo "$block" | sed -n 's/.*<a[^>]*>\(.*\)<\/a>.*/\1/p')
    url=$(echo "$block" | grep -oP 'href="\K[^"]+')
    titles+=("$title")
    urls+=("$url")
done < <(curl -sSL "https://fitgirl-repacks.site/?s=${encoded}" |
        tr '\n' ' ' |
        grep -oP '<h1 class="entry-title">.*?</h1>')

if [[ ${#titles[@]} -eq 0 ]]; then
    echo "No results found."
    exit 0
fi

echo "Results:"
for i in "${!titles[@]}"; do
    printf "%2d) %s\n" "$((i+1))" "${titles[$i]}"
done

echo
read -rp "Pick a number: " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo "Invalid input."
    exit 1
fi

idx=$((choice - 1))
if (( idx < 0 || idx >= ${#titles[@]} )); then
    echo "Choice out of range."
    exit 1
fi

picked_url="${urls[$idx]}"
picked_title="${titles[$idx]}"

folder_title=$(echo "$picked_title" | tr -cd '[:alnum:]_-' | tr ' ' '_')
extract_dir="$HOME/.local/share/Vapor/repacks/$folder_title"

echo
echo "Running downloader for: $picked_title"
echo

cd "$HOME/.local/share/Vapor"
./fitgirl-ddl "$picked_url"

txt_file=$(ls -t *.txt 2>/dev/null | grep -v '^requirements\.txt$' | head -n1)
if [[ -z "$txt_file" ]]; then
    echo "No txt file found to process."
    exit 1
fi

echo "Processing download instructions from $txt_file"
echo

parts_dir="$HOME/.local/share/Vapor/repacks/parts"
mkdir -p "$parts_dir"
mkdir -p "$extract_dir"

outfile=""
while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^[[:space:]]*out=(.*) ]]; then
        outfile="${BASH_REMATCH[1]}"
        outfile="$parts_dir/$outfile"
        continue
    fi

    if [[ "$line" =~ ^https?://fuckingfast\.co/ ]]; then
        url="$line"
        if [[ -n "$outfile" ]]; then
            echo "Downloading $outfile..."
            curl -L --fail -C - -o "$outfile" "$url"
            echo "Downloaded $outfile"
            echo
            outfile=""
        fi
    fi
done < "$txt_file"

echo "Extracting archive to $extract_dir..."
latest_rar=$(ls -1 "$parts_dir"/*.part01.rar 2>/dev/null | head -n1)
if [[ -z "$latest_rar" ]]; then
    echo "No .part01.rar file found for extraction."
    exit 1
fi

7z x "$latest_rar" -o"$extract_dir" -y
echo "Extraction completed into $extract_dir"

echo "Cleaning up downloaded RAR parts..."
rm -rf "$parts_dir"
echo "RAR parts removed."

echo
echo "All downloads, extraction, and cleanup finished for $picked_title!"
echo "Repack is ready in: $extract_dir"
