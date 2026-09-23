#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 3 ]]; then
  echo 'Usage: build-remediated-staging.sh host|candidate OUTPUT_ROOT EXPECTED_SOURCE_SHA' >&2
  exit 2
fi
role=$1
output_root_input=$2
expected_source_sha=$3
case "$role" in
  host) version=0.0.3; build=9031 ;;
  candidate) version=0.0.4; build=9032 ;;
  *) echo 'Only remediated staging host/candidate artifacts are accepted.' >&2; exit 2 ;;
esac
[[ "$expected_source_sha" =~ ^[0-9a-f]{40}$ ]] || {
  echo 'Expected a full, lowercase 40-character source SHA.' >&2; exit 2;
}

script_dir=$(cd "$(dirname "$0")" && pwd -P)
root=$(git -C "$script_dir/../.." rev-parse --show-toplevel)
root=$(cd "$root" && pwd -P)
branch=$(git -C "$root" branch --show-current)
case "$branch" in
  feature/in-app-updater-u2-u5|v3/release-candidate) ;;
  *) echo 'Refusing staging archives outside the reviewed updater context.' >&2; exit 1 ;;
esac
actual_source_sha=$(git -C "$root" rev-parse HEAD)
[[ "$actual_source_sha" == "$expected_source_sha" ]] || {
  echo "Source SHA mismatch: expected $expected_source_sha, found $actual_source_sha." >&2; exit 1;
}
[[ -z $(git -C "$root" status --porcelain) ]] || {
  echo 'Commit all source changes before creating staging artifacts.' >&2; exit 1;
}

resolved="$root/AIUsageBar.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
python3 - "$resolved" <<'PY'
import json
import sys
from pathlib import Path

pins = json.loads(Path(sys.argv[1]).read_text())["pins"]
matches = [pin for pin in pins if pin.get("identity") == "sparkle"]
if len(matches) != 1:
    raise SystemExit("Expected exactly one Sparkle package pin.")
pin = matches[0]
state = pin.get("state", {})
actual = (pin.get("location"), state.get("version"), state.get("revision"))
expected = (
    "https://github.com/sparkle-project/Sparkle",
    "2.10.0",
    "eef1a539a373c1f1a320624b1130fc5de7b2e100",
)
if actual != expected:
    raise SystemExit(f"Unexpected Sparkle package pin: {actual!r}")
PY

public_ed_key=$(tr -d '\r\n' < "$script_dir/public-key.txt")
[[ "$public_ed_key" =~ ^[A-Za-z0-9+/]{43}=$ ]] || {
  echo 'The tracked U1 staging public key is malformed.' >&2; exit 1;
}
output_root=$(mkdir -p "$output_root_input" && cd "$output_root_input" && pwd -P)
case "$output_root/" in
  "$root/"|"$root/"*)
    echo 'Staging evidence must be written outside the source repository.' >&2; exit 1;
    ;;
esac
stage="$output_root/$role"
[[ ! -e "$stage" && ! -L "$stage" ]] || {
  echo 'Staging artifacts are write-once; choose a fresh output root.' >&2; exit 1;
}
mkdir -p "$stage"
printf '%s\n' "$actual_source_sha" > "$stage/source-sha.txt"

xcodebuild \
  -project "$root/AIUsageBar.xcodeproj" \
  -scheme AIUsageBar \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -xcconfig "$script_dir/Staging-Remediated.xcconfig" \
  -derivedDataPath "$stage/DerivedData" \
  -clonedSourcePackagesDirPath "$output_root/SourcePackages" \
  -archivePath "$stage/AIUsageBar-$version-remediated-$build.xcarchive" \
  -disableAutomaticPackageResolution \
  U2_PUBLIC_ED_KEY="$public_ed_key" \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$build" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Developer ID Application' \
  DEVELOPMENT_TEAM=S898B9KBWN \
  ENABLE_HARDENED_RUNTIME=YES \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=YES \
  archive

xcodebuild -exportArchive \
  -archivePath "$stage/AIUsageBar-$version-remediated-$build.xcarchive" \
  -exportPath "$stage/export" \
  -exportOptionsPlist "$script_dir/ExportOptions.plist"

python3 "$script_dir/verify-remediated-app.py" \
  "$stage/export/AIUsageBar.app" "$version" "$build" "$expected_source_sha"
echo "PASS: remediated staging $role ($version/$build) archived from $actual_source_sha."
