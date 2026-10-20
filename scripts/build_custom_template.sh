#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUT_ZIP="${1:-$REPO_ROOT/templates/web_release.zip}"
GODOT_RELEASE="4.7.2-stable"
GODOT_DIR="${GODOT_SOURCE_DIR:-/tmp/godot-$GODOT_RELEASE}"

# Check for emcc or load emsdk
if ! command -v emcc >/dev/null 2>&1; then
    if [ -f "/tmp/emsdk/emsdk_env.sh" ]; then
        echo "Activating emsdk from /tmp/emsdk..."
        # shellcheck disable=SC1091
        source /tmp/emsdk/emsdk_env.sh
    elif [ -n "${EMSDK:-}" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
        echo "Activating emsdk from $EMSDK..."
        # shellcheck disable=SC1091
        source "$EMSDK/emsdk_env.sh"
    else
        echo "Error: emcc not found. Please install and activate emsdk (version >= 4.0.0)." >&2
        exit 1
    fi
fi

# Ensure scons is available
if ! command -v scons >/dev/null 2>&1; then
    echo "Error: scons not found. Please install scons (e.g. uv tool install scons)." >&2
    exit 1
fi

# Download Godot source if missing
if [ ! -d "$GODOT_DIR" ] || [ ! -f "$GODOT_DIR/SConstruct" ]; then
    echo "Downloading Godot $GODOT_RELEASE source..."
    mkdir -p "$GODOT_DIR"
    curl -sSL "https://github.com/godotengine/godot/archive/refs/tags/${GODOT_RELEASE}.tar.gz" | tar -xz -C "$GODOT_DIR" --strip-components=1
fi

PROFILE_PATH="$REPO_ROOT/web.gdbuild"
if [ ! -f "$PROFILE_PATH" ]; then
    echo "Error: Build profile $PROFILE_PATH not found." >&2
    exit 1
fi

NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
echo "Compiling Godot custom web release template (-j$NPROC)..."

cd "$GODOT_DIR"
scons platform=web \
    target=template_release \
    arch=wasm32 \
    threads=no \
    dlink_enabled=no \
    optimize=size_extra \
    build_profile="$PROFILE_PATH" \
    module_text_server_adv_enabled=no \
    module_text_server_fb_enabled=yes \
    -j"$NPROC"

BUILT_ZIP="$GODOT_DIR/bin/godot.web.template_release.wasm32.nothreads.zip"
if [ ! -f "$BUILT_ZIP" ]; then
    echo "Error: Expected template zip $BUILT_ZIP was not produced." >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_ZIP")"
cp "$BUILT_ZIP" "$OUTPUT_ZIP"
echo "Successfully generated custom Web release template: $OUTPUT_ZIP"
ls -lh "$OUTPUT_ZIP"
