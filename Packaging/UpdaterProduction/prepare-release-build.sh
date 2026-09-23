#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: prepare-release-build.sh 5|6 OUTPUT_ROOT PUBLIC_ED_KEY EXPIRATION_INTERVAL

Creates a signed Developer ID Xcode archive and export for Build 5 or Build 6.
The public key and expiration policy are mandatory explicit inputs. This script
does not notarize, package a DMG, generate EdDSA artifact signatures, or publish.
EOF
}

if [[ $# != 4 ]]; then usage; exit 2; fi
build=$1
output_root_input=$2
public_ed_key=$3
expiration_interval=$4
case "$build" in
  5) version=1.1.0 ;;
  6) version=1.1.1 ;;
  *) echo 'Only reserved updater builds 5 and 6 are accepted.' >&2; exit 2 ;;
esac
[[ "$expiration_interval" =~ ^[0-9]+$ ]] || {
  echo 'The production expiration decision must be an explicit non-negative integer.' >&2; exit 2;
}

script_dir=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$script_dir/../.." rev-parse --show-toplevel)
root=$(cd "$root" && pwd -P)
branch=$(git -C "$root" branch --show-current)
case "$branch" in
  main|release/*|feature/in-app-updater-u2-u5) ;;
  *) echo "Refusing release archive preparation on branch '$branch'." >&2; exit 1 ;;
esac
[[ -z $(git -C "$root" status --porcelain) ]] || {
  echo 'Commit all source changes before producing release build evidence.' >&2; exit 1;
}
resolved="$root/AIUsageBar.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
python3 - "$resolved" <<'PY'
import json
import sys
from pathlib import Path

pins = json.loads(Path(sys.argv[1]).read_text())["pins"]
matches = [pin for pin in pins if pin.get("identity") == "sparkle"]
expected = {
    "identity": "sparkle",
    "kind": "remoteSourceControl",
    "location": "https://github.com/sparkle-project/Sparkle",
    "version": "2.10.0",
    "revision": "eef1a539a373c1f1a320624b1130fc5de7b2e100",
}
if len(matches) != 1:
    raise SystemExit("Expected exactly one Sparkle package pin.")
pin = matches[0]
state = pin.get("state", {})
actual = {
    "identity": pin.get("identity"),
    "kind": pin.get("kind"),
    "location": pin.get("location"),
    "version": state.get("version"),
    "revision": state.get("revision"),
}
if actual != expected:
    raise SystemExit(f"Unexpected Sparkle package pin: {actual!r}")
PY

output_root=$(mkdir -p "$output_root_input" && cd "$output_root_input" && pwd -P)
case "$output_root/" in
  "$root/"|"$root/"*)
    echo 'Release evidence must be written outside the source repository.' >&2; exit 1;
    ;;
esac
stage="$output_root/build-$build"
[[ ! -e "$stage" && ! -L "$stage" ]] || {
  echo 'Build evidence is write-once; choose a fresh output directory.' >&2; exit 1;
}
mkdir -p "$stage"
git -C "$root" rev-parse HEAD > "$stage/source-sha.txt"
plist="$stage/Production-Info.plist"
python3 "$script_dir/generate-production-info.py" \
  --public-ed-key "$public_ed_key" \
  --expiration-interval "$expiration_interval" \
  --output "$plist"

archive="$stage/AIUsageBar-$version-build$build.xcarchive"
export_path="$stage/export"
derived_data="$stage/DerivedData"
source_packages="$stage/SourcePackages"

xcodebuild \
  -project "$root/AIUsageBar.xcodeproj" \
  -scheme AIUsageBar \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$source_packages" \
  -archivePath "$archive" \
  -disableAutomaticPackageResolution \
  INFOPLIST_FILE="$plist" \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$build" \
  DEVELOPMENT_TEAM=S898B9KBWN \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Developer ID Application' \
  ENABLE_HARDENED_RUNTIME=YES \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=YES \
  archive

xcodebuild -exportArchive \
  -archivePath "$archive" \
  -exportPath "$export_path" \
  -exportOptionsPlist "$root/Packaging/UpdaterSpike/ExportOptions.plist"

app="$export_path/AIUsageBar.app"
python3 "$script_dir/verify-release-app.py" \
  "$app" "$version" "$build" "$public_ed_key" "$expiration_interval"
/usr/bin/codesign --verify --deep --strict "$app"
details=$(/usr/bin/codesign -dv --verbose=4 "$app" 2>&1)
[[ "$details" == *'TeamIdentifier=S898B9KBWN'* ]] || {
  echo 'Exported app has the wrong Developer ID Team.' >&2; exit 1;
}
[[ "$details" == *'runtime'* ]] || {
  echo 'Exported app is missing Hardened Runtime.' >&2; exit 1;
}
arches=$(/usr/bin/lipo -archs "$app/Contents/MacOS/AIUsageBar")
[[ "$arches" == *arm64* && "$arches" == *x86_64* ]] || {
  echo "Exported app is not universal: $arches" >&2; exit 1;
}

echo "PASS: Build $build ($version) archive and Developer ID export prepared."
echo 'NOT DONE: notarization, stapling, final DMG, EdDSA artifact signature, public-feed proof, and human installation gates.'
