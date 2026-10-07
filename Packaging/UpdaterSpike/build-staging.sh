#!/bin/bash
set -euo pipefail
# Builds staging only. Never installs or launches the result.
# Staging versions never use production identities 1.0.0 (4), 1.1.0 (5) or 1.1.1 (6).
if [[ $# != 4 ]]; then
  echo "Usage: $0 host|candidate|final-host|final-candidate OUTPUT_DIRECTORY PUBLIC_ED_KEY EXPECTED_SOURCE_SHA" >&2; exit 2
fi
u1_feed=https://synok522-del.github.io/AIUsageBar/staging/u1-20260915/appcast.xml
final_feed=https://synok522-del.github.io/AIUsageBar/staging/final-20260924/appcast.xml
case "$1" in
  host) version=0.0.1; build=9001; feed=$u1_feed ;;
  candidate) version=0.0.2; build=9002; feed=$u1_feed ;;
  final-host) version=0.0.3; build=9003; feed=$final_feed ;;
  final-candidate) version=0.0.4; build=9004; feed=$final_feed ;;
  *) echo 'Only staging host/candidate builds are permitted.' >&2; exit 2 ;;
esac
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
# Provenance, not branch name: the checkout must be exactly the reviewed commit.
[[ "$4" =~ ^[0-9a-f]{40}$ && $(git -C "$root" rev-parse HEAD) == "$4" ]] || {
  echo 'HEAD is not the expected reviewed source SHA.' >&2; exit 1;
}
[[ -z $(git -C "$root" status --porcelain) ]] || {
  echo 'Commit all source changes before recording binary provenance.' >&2; exit 1;
}
[[ "$3" =~ ^[A-Za-z0-9+/]{43}=$ ]] || { echo 'Expected a public Ed25519 key.' >&2; exit 2; }
mkdir -p "$2"
out=$(cd "$2" && pwd)
[[ ! -e "$out/$1.xcarchive" && ! -e "$out/$1-export" ]] || {
  echo 'Use a fresh output directory; staging builds are write-once.' >&2; exit 1;
}
xcodebuild -project "$root/AIUsageBar.xcodeproj" -scheme AIUsageBar \
  -configuration Release -xcconfig "$root/Packaging/UpdaterSpike/Staging.xcconfig" \
  -clonedSourcePackagesDirPath "$out/SourcePackages" \
  -derivedDataPath "$out/DerivedData-$1" -archivePath "$out/$1.xcarchive" \
  -disableAutomaticPackageResolution \
  U1_PUBLIC_ED_KEY="$3" STAGING_FEED_URL="$feed" MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Developer ID Application' archive
xcodebuild -exportArchive -archivePath "$out/$1.xcarchive" \
  -exportPath "$out/$1-export" \
  -exportOptionsPlist "$root/Packaging/UpdaterSpike/ExportOptions.plist"

# Verify the actual exported version; xcconfig values can override command-line settings.
[[ $(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$out/$1-export/AIUsageBar.app/Contents/Info.plist") == "$version" ]]
[[ $(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$out/$1-export/AIUsageBar.app/Contents/Info.plist") == "$build" ]]
[[ $(/usr/libexec/PlistBuddy -c "Print SUFeedURL" "$out/$1-export/AIUsageBar.app/Contents/Info.plist") == "$feed" ]]
[[ $(/usr/libexec/PlistBuddy -c "Print SUPublicEDKey" "$out/$1-export/AIUsageBar.app/Contents/Info.plist") == "$3" ]]
