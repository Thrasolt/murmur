#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/.build/Murmur.app"
SIGNING_IDENTITY="${MURMUR_SIGNING_IDENTITY:--}"

cd "$ROOT"
mkdir -p "$ROOT/.build/clang-module-cache"
CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-module-cache" \
  swift build -c release --scratch-path .build/scratch --cache-path .build/cache
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/.build/scratch/out/Products/Release/Murmur" "$APP/Contents/MacOS/Murmur"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP"
printf 'Built %s\n' "$APP"
