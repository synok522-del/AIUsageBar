#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 3 ]]; then
  echo 'Usage: prepare-build5-rc.sh OUTPUT_ROOT PUBLIC_ED_KEY EXPIRATION_INTERVAL' >&2
  echo 'The interval is a required human production decision; no default is supplied.' >&2
  exit 2
fi
exec "$(dirname "$0")/prepare-release-build.sh" 5 "$1" "$2" "$3"
