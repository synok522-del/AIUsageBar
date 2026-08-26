#!/bin/sh

# Creates a repeatable drag-to-install DMG layout for local packaging.
# This script only creates the layout image; signing and notarization remain
# separate release steps and are intentionally not performed here.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

usage() {
    echo "Usage: $0 /path/to/AIUsageBar.app /path/to/output.dmg" >&2
    exit 2
}

[ "$#" -eq 2 ] || usage

APP_PATH=$1
OUTPUT_PATH=$2

[ -d "$APP_PATH" ] || {
    echo "App not found: $APP_PATH" >&2
    exit 1
}

TEMP_ROOT=$(mktemp -d "${TMPDIR:-/private/tmp}/AIUsageBar-DMG.XXXXXX")
STAGING="$TEMP_ROOT/staging"
MOUNT_POINT="$TEMP_ROOT/mount"
RW_DMG="$TEMP_ROOT/AIUsageBar-rw.dmg"
BACKGROUND_GENERATOR="$TEMP_ROOT/make-dmg-background"
MOUNTED=0

APP_SIZE_KB=$(du -sk "$APP_PATH" | awk '{print $1}')
case "$APP_SIZE_KB" in
    ''|*[!0-9]*)
        echo "Unable to determine App size" >&2
        exit 1
        ;;
esac
IMAGE_SIZE_KB=$((APP_SIZE_KB + 50 * 1024))

detach_mounted_volume() {
    attempt=1

    while [ "$attempt" -le 5 ]; do
        if hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1; then
            MOUNTED=0
            return 0
        fi

        sleep 1
        attempt=$((attempt + 1))
    done

    if hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1; then
        MOUNTED=0
        return 0
    fi

    echo "Unable to detach DMG mount point: $MOUNT_POINT" >&2
    return 1
}

cleanup() {
    if [ "$MOUNTED" -eq 1 ]; then
        detach_mounted_volume || true
    fi
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT INT TERM

mkdir -p "$STAGING/.background" "$MOUNT_POINT"
ditto --norsrc --noextattr "$APP_PATH" "$STAGING/AIUsageBar.app"
ln -s /Applications "$STAGING/Applications"

swiftc "$SCRIPT_DIR/DMGBackground.swift" -o "$BACKGROUND_GENERATOR"
"$BACKGROUND_GENERATOR" "$STAGING/.background/arrow.png"

hdiutil create \
    -volname "AIUsageBar" \
    -srcfolder "$STAGING" \
    -size "${IMAGE_SIZE_KB}k" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "$RW_DMG" >/dev/null

hdiutil attach "$RW_DMG" \
    -readwrite \
    -noverify \
    -noautoopen \
    -mountpoint "$MOUNT_POINT" >/dev/null
MOUNTED=1

VOLUME_NAME=$(basename "$MOUNT_POINT")
osascript "$SCRIPT_DIR/configure-dmg-layout.applescript" "$MOUNT_POINT" "$VOLUME_NAME"
sleep 2
/bin/sync
detach_mounted_volume

mkdir -p "$(dirname -- "$OUTPUT_PATH")"
hdiutil convert "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "$OUTPUT_PATH" >/dev/null

echo "Created DMG layout: $OUTPUT_PATH"
