#!/usr/bin/env python3
"""Generate a typed production Sparkle plist from explicit release inputs."""

import argparse
import base64
import plistlib
import re
from pathlib import Path

FEED_URL = "https://synok522-del.github.io/AIUsageBar/appcast.xml"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--public-ed-key", required=True)
    parser.add_argument("--expiration-interval", required=True, type=int)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    if not re.fullmatch(r"[A-Za-z0-9+/]{43}=", args.public_ed_key):
        parser.error("--public-ed-key must be a base64 Ed25519 public key")
    try:
        key_bytes = base64.b64decode(args.public_ed_key, validate=True)
    except ValueError:
        parser.error("--public-ed-key is not valid base64")
    if len(key_bytes) != 32:
        parser.error("--public-ed-key must decode to exactly 32 bytes")
    if args.expiration_interval < 0:
        parser.error("--expiration-interval must be an explicit non-negative integer")
    if args.output.exists() or args.output.is_symlink():
        parser.error("refusing to overwrite an existing production plist")

    info = {
        "SUFeedURL": FEED_URL,
        "SUPublicEDKey": args.public_ed_key,
        "SURequireSignedFeed": True,
        "SUVerifyUpdateBeforeExtraction": True,
        "SUEnableAutomaticChecks": True,
        "SUAutomaticallyUpdate": False,
        "SUAllowsAutomaticUpdates": False,
        "SUEnableJavaScript": False,
        "SUEnableSystemProfiling": False,
        "SUSignedFeedFailureExpirationInterval": args.expiration_interval,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("xb") as output:
        plistlib.dump(info, output, fmt=plistlib.FMT_XML, sort_keys=True)
    print(f"Created typed production updater plist: {args.output}")
    print(f"Feed: {FEED_URL}")
    print(f"Feed failure expiration interval: {args.expiration_interval} seconds (explicit input)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
