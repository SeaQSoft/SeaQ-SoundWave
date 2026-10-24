#!/bin/sh
# Builds SeaQ-SoundWave-<version>.plasmoid (only what the widget needs).
set -e
cd "$(dirname "$0")/.."
VERSION="$(python3 -c 'import json;print(json.load(open("metadata.json"))["KPlugin"]["Version"])')"
OUT="SeaQ-SoundWave-$VERSION.plasmoid"
rm -f "$OUT"
find contents -name __pycache__ -prune -exec rm -rf {} +
zip -qr "$OUT" metadata.json contents LICENSE
echo "→ $OUT"
