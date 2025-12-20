# Vapor ( END OF LIFE )
A menu for various tools and automation scripts for Steam on linux.

## For installation:

```bash
curl -fsSL https://raw.githubusercontent.com/dim-ghub/Vapor/refs/heads/main/Installer.sh | bash
```

Sometimes it wont download the released binary which is required, so check for its existence at `~/.local/share/Vapor/DepotDownloaderMod`

If not there, grab it from releases and put it in the folder.

## Dependencies:

`curl jq mpv git python3 python3-venv tk 7z`

Obtain a morrenus api key at:
https://manifest.morrenus.xyz/

## Configuration:
A config file will be created on first run, alternatively use the flags below:

`--skip-intro`

Skips the title sequence

`--nosound`

Disables sound effects and theme music
