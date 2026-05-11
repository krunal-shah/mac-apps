#!/usr/bin/env bash
# Direct swiftc build, used when Swift Package Manager is unavailable
# (e.g. Command Line Tools install missing PackageDescription module).
#
# Produces .build/release/GoLinks, the same path `swift build -c release`
# would write. This lets the existing Makefile `app` / `install` targets
# pick up the binary without further changes.

set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR=".build/release"
OUT_BIN="$OUT_DIR/GoLinks"
TARGET_TRIPLE="${TARGET_TRIPLE:-$(uname -m)-apple-macos13.0}"

mkdir -p "$OUT_DIR"

# Collect all Swift sources, NUL-delimited to survive paths with spaces.
find Sources/CommandShelf -name '*.swift' -print0 \
  | xargs -0 swiftc \
      -O \
      -target "$TARGET_TRIPLE" \
      -framework AppKit \
      -framework SwiftUI \
      -framework Foundation \
      -framework Network \
      -framework Carbon \
      -framework Security \
      -framework UniformTypeIdentifiers \
      -o "$OUT_BIN"

echo "✓ Built $OUT_BIN ($(stat -f%z "$OUT_BIN") bytes)"
