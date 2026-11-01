#!/usr/bin/env bash
# Draws the artwork and builds assets/AppIcon.icns. Needs only macOS built-ins.
set -euo pipefail
cd "$(dirname "$0")/.."

swift scripts/make-assets.swift assets

SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"
for size in 16 32 128 256 512; do
  sips -z $size $size assets/icon.png --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) assets/icon.png --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o assets/AppIcon.icns
echo "Built assets/AppIcon.icns"
