#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 4 ]]; then
  echo 'Usage: notarize-remediated-dmg.sh STAGING_APP OUTPUT_ROOT NOTARY_PROFILE EXPECTED_SOURCE_SHA' >&2
  exit 2
fi
app=$(cd "$1" && pwd -P)
output_root_input=$2
notary_profile=$3
source_sha=$4
root=$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel)
root=$(cd "$root" && pwd -P)
[[ "$app" != /Applications/* && "$app" != */Downloads/* ]] || {
  echo 'Refusing an installed or downloaded app; use the isolated staging export.' >&2; exit 1;
}
case "$app/" in
  "$root/"*) echo 'Refusing to notarize an app inside the source repository.' >&2; exit 1 ;;
esac
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || {
  echo 'Expected a full, lowercase 40-character source SHA.' >&2; exit 2;
}
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")
case "$version:$build" in
  0.0.3:9031|0.0.4:9032) ;;
  *) echo 'Not a remediated staging export; refusing to notarize.' >&2; exit 1 ;;
esac
python3 "$(dirname "$0")/verify-remediated-app.py" "$app" "$version" "$build" "$source_sha"
commit_file="$app/Contents/Resources/GitCommit.plist"
[[ -f "$commit_file" ]] || { echo 'Missing embedded GitCommit provenance.' >&2; exit 1; }
embedded_sha=$(/usr/libexec/PlistBuddy -c 'Print GitCommit' "$commit_file")
[[ "$embedded_sha" == "${source_sha:0:7}" ]] || {
  echo 'Embedded source commit does not match expected source SHA.' >&2; exit 1;
}
source_sha_file="$(dirname "$app")/../source-sha.txt"
[[ -f "$source_sha_file" && "$(cat "$source_sha_file")" == "$source_sha" ]] || {
  echo 'Full source SHA sidecar does not match the exported app.' >&2; exit 1;
}

mkdir -p "$output_root_input"
out=$(cd "$output_root_input" && pwd -P)
case "$out/" in
  "$root/"|"$root/"*)
    echo 'Staging notarization evidence must be written outside the source repository.' >&2; exit 1;
    ;;
esac
dmg="$out/AIUsageBar-$version-u2-remediated-$build.dmg"
[[ ! -e "$dmg" && ! -L "$dmg" ]] || {
  echo 'Refusing to replace an existing staging installer.' >&2; exit 1;
}
app_zip="$out/app-$build-notary.zip"
dmg_notary_json="$out/dmg-$build-notary.json"
app_notary_json="$out/app-$build-notary.json"
[[ ! -e "$app_zip" && ! -e "$app_notary_json" && ! -e "$dmg_notary_json" ]] || {
  echo 'Notary evidence is write-once; choose a fresh output root.' >&2; exit 1;
}

ditto -c -k --sequesterRsrc --keepParent "$app" "$app_zip"
xcrun notarytool submit "$app_zip" --keychain-profile "$notary_profile" --wait --output-format json > "$app_notary_json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$app_notary_json"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --deep --strict "$app"
spctl --assess --type execute --verbose=2 "$app"

"$root/Packaging/create-dmg.sh" "$app" "$dmg"
codesign --force --timestamp --sign 'Developer ID Application: Wei Kai Hung (S898B9KBWN)' "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$notary_profile" --wait --output-format json > "$dmg_notary_json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$dmg_notary_json"
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
codesign --verify --strict "$dmg"
python3 "$root/Packaging/UpdaterSpike/verify-remediated-dmg.py" "$dmg" "$app" "$version" "$build" "$source_sha"

# EdDSA signing happens only after the final stapled DMG is frozen.
shasum -a 256 "$dmg" > "$dmg.sha256"
stat -f '%z' "$dmg" > "$dmg.size"
printf '%s\n' "$source_sha" > "$dmg.source-sha"
echo "PASS: final notarized and stapled staging DMG: $dmg"
