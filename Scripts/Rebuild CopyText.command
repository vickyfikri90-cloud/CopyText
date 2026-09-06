#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "→ Stopping CopyText if running..."
pkill -x CopyText 2>/dev/null || true

echo "→ Building Release..."
xcodebuild -project CopyText.xcodeproj -scheme CopyText -configuration Release \
  -derivedDataPath /tmp/CopyText-build-auto CODE_SIGN_IDENTITY="-" build

echo "→ Replacing dist/CopyText.app..."
rm -rf dist/CopyText.app
ditto /tmp/CopyText-build-auto/Build/Products/Release/CopyText.app dist/CopyText.app

echo "→ Launching..."
open dist/CopyText.app

echo ""
echo "Done. App updated at:"
echo "$PROJECT_DIR/dist/CopyText.app"
