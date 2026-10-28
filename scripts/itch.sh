#!/usr/bin/env bash
# Export the desktop builds, then push them to itch.io
# (channels mac, windows, linux).
#USAGE arg "[version]" help="Version shown on itch.io, like v1.2.3 (default: git describe)"
#USAGE flag "--skip-export" help="Push the existing build/ outputs without re-exporting"
set -euo pipefail
version="${usage_version:-$(git describe --tags --always --dirty)}"

# Fail before the slow exports if butler can't log in or the itch.io project is wrong.
bash scripts/itch_preflight.sh

if [[ "${usage_skip_export:-false}" != true ]]; then
  mise run export-desktop
fi

for f in "build/macos/Stroad Hero.zip" build/windows/StroadHero.{exe,pck} build/linux/StroadHero.{x86_64,pck}; do
  [[ -f "$f" ]] || { echo "missing $f; run without --skip-export" >&2; exit 1; }
done

# Stage exactly what ships, so stray files in build/ never reach itch.io.
rm -rf build/itch
mkdir -p build/itch/mac build/itch/windows build/itch/linux
ditto -x -k "build/macos/Stroad Hero.zip" build/itch/mac
cp build/windows/StroadHero.{exe,pck} build/itch/windows/
cp build/linux/StroadHero.{x86_64,pck} build/itch/linux/

echo "Pushing $version to $ITCH_TARGET"
for channel in mac windows linux; do
  butler push "build/itch/$channel" "$ITCH_TARGET:$channel" --userversion "$version"
done
