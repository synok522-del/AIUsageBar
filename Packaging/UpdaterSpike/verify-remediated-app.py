#!/usr/bin/env python3
"""Verify a remediated staging export without launching or installing it."""
import pathlib
import plistlib
import re
import subprocess
import sys

if len(sys.argv) != 5:
    raise SystemExit("usage: verify-remediated-app.py APP VERSION BUILD SOURCE_SHA")
app = pathlib.Path(sys.argv[1]).resolve()
version, build, source_sha = sys.argv[2:5]
if (version, build) not in {("0.0.3", "9031"), ("0.0.4", "9032")}:
    raise SystemExit("refusing non-remediated staging version/build")
if not re.fullmatch(r"[0-9a-f]{40}", source_sha):
    raise SystemExit("expected a full lowercase source SHA")

info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
staging_key = pathlib.Path(__file__).with_name("public-key.txt").read_text().strip()
expected = {
    "CFBundleIdentifier": "synok522.AIUsageBar",
    "CFBundleShortVersionString": version,
    "CFBundleVersion": build,
    "LSMinimumSystemVersion": "13.0",
    "SUFeedURL": "https://synok522-del.github.io/AIUsageBar/staging/u2-remediated-20260923/appcast.xml",
    "SUPublicEDKey": staging_key,
    "SURequireSignedFeed": True,
    "SUVerifyUpdateBeforeExtraction": True,
    "SUEnableAutomaticChecks": True,
    "SUAutomaticallyUpdate": False,
    "SUAllowsAutomaticUpdates": False,
    "SUEnableJavaScript": False,
    "SUEnableSystemProfiling": False,
    "SUSignedFeedFailureExpirationInterval": 0,
}
for key, value in expected.items():
    if info.get(key) != value:
        raise SystemExit(f"FAIL: {key} expected {value!r}, got {info.get(key)!r}")
if info.get("LSUIElement") not in (True, "YES"):
    raise SystemExit("FAIL: LSUIElement is not enabled")

commit_file = app / "Contents/Resources/GitCommit.plist"
if commit_file.exists():
    git_commit = plistlib.loads(commit_file.read_bytes()).get("GitCommit")
    if git_commit != source_sha[:7]:
        raise SystemExit(f"FAIL: embedded source prefix {git_commit!r} does not match {source_sha[:7]}")

def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, check=True)
    return result.stdout + result.stderr

run("codesign", "--verify", "--deep", "--strict", str(app))
details = run("codesign", "-dv", "--verbose=4", str(app))
if "TeamIdentifier=S898B9KBWN" not in details or "runtime" not in details:
    raise SystemExit("FAIL: exported app lacks expected Developer ID Team or Hardened Runtime")
architectures = set(run("lipo", "-archs", str(app / "Contents/MacOS/AIUsageBar")).split())
if architectures != {"arm64", "x86_64"}:
    raise SystemExit(f"FAIL: expected universal app, got {sorted(architectures)}")
print(f"PASS: {version} ({build}), Sparkle 2.10.0 staging policy, Developer ID and universal slices")
