#!/bin/bash
# Internal validation only. No production signing inputs, releases, tags or feeds.
set -euo pipefail
cd "$(dirname "$0")/../.."
source_sha="$(git rev-parse HEAD)"
[[ -z "$(git status --porcelain)" ]] || { echo 'Refusing to package a dirty source tree'; exit 1; }
[[ "${EXPECTED_SHA:-$source_sha}" == "$source_sha" ]] || exit 1
output_dir="${VALIDATION_OUTPUT_DIR:-${TMPDIR:-/tmp}/AIUsageBar-LiveValidation-${source_sha}}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
derived_data="$output_dir/DerivedData"
plist="$output_dir/Validation-Info.plist"
python3 - "$plist" "$source_sha" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as f:
    plistlib.dump({
        'CFBundleIdentifier': 'synok522.AIUsageBar.LiveValidation',
        'CFBundleName': 'AIUsageBar Live Validation',
        'CFBundleDisplayName': 'AIUsageBar Live Validation',
        'CFBundleExecutable': 'AIUsageBar Live Validation',
        'CFBundlePackageType': 'APPL',
        'CFBundleShortVersionString': '1.1.1',
        'CFBundleVersion': '826',
        'LSUIElement': True,
        'LSMinimumSystemVersion': '13.0',
        'NSHighResolutionCapable': True,
        'AIUsageBarLiveValidation': True,
        'GitCommit': sys.argv[2],
    }, f)
PY
xcodebuild -project AIUsageBar.xcodeproj -scheme AIUsageBar -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$derived_data" \
    'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    PRODUCT_NAME='AIUsageBar Live Validation' PRODUCT_MODULE_NAME=AIUsageBar \
    PRODUCT_BUNDLE_IDENTIFIER=synok522.AIUsageBar.LiveValidation \
    GENERATE_INFOPLIST_FILE=NO INFOPLIST_FILE="$plist" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS=LIVE_VALIDATION \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO ENABLE_HARDENED_RUNTIME=NO build
app="$derived_data/Build/Products/Release/AIUsageBar Live Validation.app"
# Ad-hoc signatures make the universal bundle internally consistent. No identity/key is used.
codesign --force --deep --sign - "$app"
python3 Packaging/LiveValidation/verify.py "$app" "$source_sha"
"$app/Contents/MacOS/AIUsageBar Live Validation" --live-validation-smoke
# Exercise the actual menu-bar application's startup in a clean runner session.
"$app/Contents/MacOS/AIUsageBar Live Validation" &
validation_pid=$!
trap 'kill "$validation_pid" 2>/dev/null || true' EXIT
sleep 12
kill -0 "$validation_pid"
kill "$validation_pid"
wait "$validation_pid" || true
trap - EXIT
package_dir="$output_dir/Download"
mkdir -p "$package_dir"
archive="AIUsageBar-LiveValidation-${source_sha}.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$package_dir/$archive"
cp Packaging/LiveValidation/{INSTALL.md,RESULTS.md} "$package_dir/"
(
    cd "$package_dir"
    shasum -a 256 "$archive" > SHA256SUMS
)
{
    echo "Source SHA: $source_sha"
    echo 'Flavor: LIVE_VALIDATION; version 1.1.1 (826); macOS 13+; arm64 + x86_64'
    echo 'Signing: ad-hoc only; NOT Developer ID signed; NOT notarized.'
    echo 'No production signing keys, appcast, tag or release used.'
    echo "Workflow: ${GITHUB_SERVER_URL:-local}/${GITHUB_REPOSITORY:-local}/actions/runs/${GITHUB_RUN_ID:-local}"
    xcodebuild -version
    sw_vers
    codesign --display --verbose=2 "$app" 2>&1
    lipo -archs "$app/Contents/MacOS/AIUsageBar Live Validation"
    cat "$package_dir/SHA256SUMS"
} > "$package_dir/PROVENANCE.txt"
# Verify the distributed archive, not only the source app.
extracted="$output_dir/ArchiveCheck"
mkdir -p "$extracted"
ditto -x -k "$package_dir/$archive" "$extracted"
python3 Packaging/LiveValidation/verify.py "$extracted/AIUsageBar Live Validation.app" "$source_sha"
codesign --verify --deep --strict "$extracted/AIUsageBar Live Validation.app"
echo "PASS: package at $package_dir"
