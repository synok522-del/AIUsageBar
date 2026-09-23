#!/usr/bin/env python3
"""Verify a release export's updater plist and version identity."""

import plistlib
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 6:
        raise SystemExit("usage: verify-release-app.py APP VERSION BUILD PUBLIC_ED_KEY EXPIRATION_INTERVAL")
    app = Path(sys.argv[1])
    version, build, expected_key = sys.argv[2:5]
    expected_interval = int(sys.argv[5])
    info_path = app / "Contents/Info.plist"
    with info_path.open("rb") as stream:
        info = plistlib.load(stream)

    expected = {
        "CFBundleIdentifier": "synok522.AIUsageBar",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build,
        "SUFeedURL": "https://synok522-del.github.io/AIUsageBar/appcast.xml",
        "SUPublicEDKey": expected_key,
        "SURequireSignedFeed": True,
        "SUVerifyUpdateBeforeExtraction": True,
        "SUEnableAutomaticChecks": True,
        "SUAutomaticallyUpdate": False,
        "SUAllowsAutomaticUpdates": False,
        "SUEnableJavaScript": False,
        "SUEnableSystemProfiling": False,
        "SUSignedFeedFailureExpirationInterval": expected_interval,
    }
    for key, value in expected.items():
        if info.get(key) != value:
            raise SystemExit(f"FAIL: {key} expected {value!r}, got {info.get(key)!r}")
    print(f"PASS: production updater settings and app identity verified for {version} ({build})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
