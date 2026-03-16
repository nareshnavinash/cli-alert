#!/usr/bin/env bash
# generate-icon.sh — Generate cli-alert icon assets
# Renders the radar-ping icon into .iconset/ sizes, converts to .icns, and exports Linux PNG.
# Requires: Python 3 + Pillow (pip install Pillow)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Generating cli-alert icon..."

# Find a Python with Pillow
find_python() {
  for py in python3 python; do
    if command -v "$py" &>/dev/null && "$py" -c "from PIL import Image" 2>/dev/null; then
      echo "$py"
      return 0
    fi
  done
  return 1
}

PYTHON=$(find_python) || {
  echo >&2 "Error: Python 3 with Pillow is required."
  echo >&2 "  Install: pip install Pillow"
  exit 1
}

# Generate icons
"$PYTHON" "${SCRIPT_DIR}/generate-icon.py"

echo ""
echo "Done! Icon assets generated."
