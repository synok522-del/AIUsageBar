#!/bin/bash
set -euo pipefail
# Builds staging only. Never installs or launches the result.
if [[ $# != 3 ]]; then
  echo "Usage: $0 host|candidate OUTPUT_DIRECTORY PUBLIC_ED_KEY" >&2; exit 2
fi
case "$1" in
  host) version=0.0.1; build=9001 ;;
  candidate) version=0.0.2; build=9002 ;;
  *) echo 'Only host/candidate staging builds are permitted.' >&2; exit 2 ;;
esac
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
[[ $(git -C "$root" branch --show-current) == feature/in-app-updater-u0-u1 ]] || {
  echo 'Refusing to build outside the isolated U1 branch.' >&2; exit 1;
}
[[ -z $(git -C "$root" status --porcelain --untracked-files=no) ]] || {
  echo 'Commit tracked source changes before recording binary provenance.' >&2; exit 1;
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
  U1_PUBLIC_ED_KEY="$3" MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Developer ID Application' archive
xcodebuild -exportArchive -archivePath "$out/$1.xcarchive" \
  -exportPath "$out/$1-export" \
  -exportOptionsPlist "$root/Packaging/UpdaterSpike/ExportOptions.plist"

# Verify the actual exported version; xcconfig values can override command-line settings.
[[ $(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$out/$1-export/AIUsageBar.app/Contents/Info.plist") == "$version" ]]
[[ $(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$out/$1-export/AIUsageBar.app/Contents/Info.plist") == "$build" ]]
