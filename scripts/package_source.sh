#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/source"
MANIFEST="$OUT_DIR/MANIFEST.txt"

FILES=(
  "Client.py"
  "Server.py"
  "Packet.py"
  "VideoStream.py"
  "test_multicast.py"
  "requirements.txt"
  "movie.Mjpeg"
)

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

: > "$MANIFEST"
echo "Packaged files:" >> "$MANIFEST"

for file in "${FILES[@]}"; do
  cp "$ROOT_DIR/$file" "$OUT_DIR/$file"
  echo "- $file" | tee -a "$MANIFEST"
done

echo >> "$MANIFEST"
echo "Excluded from source package:" >> "$MANIFEST"
echo "- .docs/" | tee -a "$MANIFEST"
echo "- scripts/" | tee -a "$MANIFEST"
echo "- Multicast_Video_Streaming_Project_Requirement.docx" | tee -a "$MANIFEST"
echo "- __pycache__/" | tee -a "$MANIFEST"

echo
echo "Source package created at: $OUT_DIR"
echo "Manifest written to: $MANIFEST"
