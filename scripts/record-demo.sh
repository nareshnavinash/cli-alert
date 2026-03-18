#!/usr/bin/env bash
# Records the demo and converts to GIF
# Requires: asciinema, agg (https://github.com/asciinema/agg)
set -euo pipefail

# asciinema requires a UTF-8 locale
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CAST_FILE="${SCRIPT_DIR}/../assets/demo.cast"
GIF_FILE="${SCRIPT_DIR}/../assets/demo.gif"

echo "Recording demo..."
asciinema rec "$CAST_FILE" --command "bash ${SCRIPT_DIR}/demo-record.sh" --cols 100 --rows 30 --overwrite

echo "Converting to GIF..."
if command -v agg &>/dev/null; then
  agg "$CAST_FILE" "$GIF_FILE" --theme dracula --font-size 16 --speed 1.5
  cp "$GIF_FILE" "${SCRIPT_DIR}/../docs/demo.gif"
  echo "GIF saved to $GIF_FILE (and copied to docs/demo.gif)"
else
  echo "Install agg to convert: cargo install --git https://github.com/asciinema/agg"
  echo "Cast file saved to $CAST_FILE"
fi
