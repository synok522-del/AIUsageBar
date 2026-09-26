#!/bin/bash
set -euo pipefail
# No installs or app launches. Input must be a staging app, never Build 4/5/6.
[[ $# == 3 ]] || { echo "Usage: $0 STAGING_APP OUTPUT_DIRECTORY NOTARY_PROFILE" >&2; exit 2; }
app=$(cd "$1" && pwd)
[[ "$app" != /Applications/* && "$app" != */Downloads/* ]] || exit 2
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")
case "$version:$build" in
  0.0.1:9001|0.0.2:9002) label=u1 ;;
  0.0.3:9003|0.0.4:9004) label=final ;;
  *) echo 'Not a staging app.' >&2; exit 2;;
esac
[[ $(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist") == synok522.AIUsageBar ]] || exit 2
codesign --verify --deep --strict "$app"
codesign -dv "$app" 2>&1 | grep 'TeamIdentifier=S898B9KBWN' > /dev/null
mkdir -p "$2"
out=$(cd "$2" && pwd)
dmg="$out/AIUsageBar-$version-$label-$build.dmg"
[[ ! -e "$dmg" ]] || { echo 'Refusing to replace an existing installer.' >&2; exit 1; }
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
submission="$out/app-$build-notary.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$submission"
xcrun notarytool submit "$submission" --keychain-profile "$3" --wait --output-format json > "$out/app-$build-notary.json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$out/app-$build-notary.json"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --deep --strict "$app"
spctl --assess --type execute --verbose=2 "$app"
"$root/Packaging/create-dmg.sh" "$app" "$dmg"
codesign --force --timestamp --sign 'Developer ID Application: Wei Kai Hung (S898B9KBWN)' "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$3" --wait --output-format json > "$out/dmg-$build-notary.json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$out/dmg-$build-notary.json"
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
codesign --verify --strict "$dmg"
# Nothing may modify the DMG beyond this point. EdDSA signing is a later step.
shasum -a 256 "$dmg" > "$dmg.sha256"
stat -f '%z' "$dmg" > "$dmg.size"
echo "Final DMG frozen: $dmg"
