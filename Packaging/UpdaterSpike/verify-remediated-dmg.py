#!/usr/bin/env python3
"""Inspect a remediated staging DMG without launching or installing it."""
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

if len(sys.argv) != 6:
    raise SystemExit("usage: verify-remediated-dmg.py DMG APP VERSION BUILD SOURCE_SHA")
image = Path(sys.argv[1]).resolve()
canonical = Path(sys.argv[2]).resolve()
version, build, source_sha = sys.argv[3:6]

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout

def inventory(root):
    result = {}
    for path in root.rglob("*"):
        relative = str(path.relative_to(root))
        if path.is_symlink():
            result[relative] = {"symlink": str(path.readlink())}
        elif path.is_file():
            result[relative] = {
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "mode": stat.S_IMODE(path.stat().st_mode),
            }
    return result

run("codesign", "--verify", "--strict", str(image))
run("xcrun", "stapler", "validate", str(image))
run("spctl", "--assess", "--type", "open", "--context", "context:primary-signature", str(image))
with tempfile.TemporaryDirectory(prefix="AIUsageBar-U2-inspect-") as mount:
    attached = False
    try:
        run("hdiutil", "attach", str(image), "-readonly", "-nobrowse", "-noautoopen", "-mountpoint", mount)
        attached = True
        root = Path(mount)
        apps = list(root.glob("*.app"))
        if [app.name for app in apps] != ["AIUsageBar.app"]:
            raise SystemExit("FAIL: DMG must contain exactly one AIUsageBar.app")
        if not (root / "Applications").is_symlink() or str((root / "Applications").readlink()) != "/Applications":
            raise SystemExit("FAIL: missing standard Applications shortcut")
        staged_app = apps[0]
        run(
            sys.executable,
            str(Path(__file__).with_name("verify-remediated-app.py")),
            str(staged_app),
            version,
            build,
            source_sha,
        )
        if inventory(staged_app) != inventory(canonical):
            raise SystemExit("FAIL: DMG payload differs from the stapled canonical app")
    finally:
        if attached:
            run("hdiutil", "detach", mount)
print(json.dumps({
    "image": image.name,
    "sha256": hashlib.sha256(image.read_bytes()).hexdigest(),
    "size": image.stat().st_size,
    "source_sha": source_sha,
    "payload": "PASS",
    "detach": "PASS",
}, indent=2))
