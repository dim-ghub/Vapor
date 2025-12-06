#!/usr/bin/env bash
set -e

VENV_DIR="$HOME/.local/share/Vapor/venv"
PYTHON_BIN="$VENV_DIR/bin/python"
REQS_FILE="$HOME/.local/share/Vapor/requirements.txt"

echo "===== Vapor Setup ====="

if [[ ! -d "$VENV_DIR" ]]; then
    echo "[1/1] Creating virtual environment at $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
else
    echo "[1/1] Virtual environment already exists."
fi

"$PYTHON_BIN" -m pip install --upgrade pip

if [[ -f "$REQS_FILE" ]]; then
    echo "Installing dependencies from requirements.txt..."
    "$PYTHON_BIN" -m pip install -r "$REQS_FILE"
else
    echo "Warning: requirements.txt not found at $REQS_FILE"
fi

"$PYTHON_BIN" -m pip install pycryptodome

echo "Virtual environment setup complete!"
echo "You can now run the main script using: $PYTHON_BIN storage_depotdownloadermod.py"
