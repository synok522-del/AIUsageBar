#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 4 ]]; then
  echo 'Usage: prepare-build6-proof.sh OUTPUT_ROOT PUBLIC_ED_KEY EXPIRATION_INTERVAL EXPECTED_SOURCE_SHA' >&2
  echo 'Build 6 preparation does not run the installed-host proof or publish a feed.' >&2
  exit 2
fi
exec "$(dirname "$0")/prepare-release-build.sh" 6 "$1" "$2" "$3" "$4"
