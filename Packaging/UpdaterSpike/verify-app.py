#!/usr/bin/env python3
"""Read-only inspection of a staging app. Never reads credentials or launches it."""
import json
import pathlib
import plistlib
import re
import subprocess
import sys

app = pathlib.Path(sys.argv[1]).resolve()
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
assert (info['CFBundleShortVersionString'], info['CFBundleVersion']) in {('0.0.1', '9001'), ('0.0.2', '9002')}
assert info['CFBundleIdentifier'] == 'synok522.AIUsageBar'
assert info['LSMinimumSystemVersion'] == '13.0'
assert info['LSUIElement'] in (True, 'YES')
for key in ('SURequireSignedFeed', 'SUVerifyUpdateBeforeExtraction', 'SUEnableAutomaticChecks'):
    assert info[key] in (True, 'YES'), key
for key in ('SUAutomaticallyUpdate', 'SUAllowsAutomaticUpdates', 'SUEnableJavaScript', 'SUEnableSystemProfiling'):
    assert info[key] in (False, 'NO'), key
assert str(info['SUSignedFeedFailureExpirationInterval']) == '0'
assert info['SUFeedURL'] == 'https://synok522-del.github.io/AIUsageBar/staging/u1-20260915/appcast.xml'
assert re.fullmatch(r'[A-Za-z0-9+/]{43}=', info['SUPublicEDKey'])

def run(*args):
    p = subprocess.run(args, capture_output=True, text=True, check=True)
    return p.stdout + p.stderr

run('codesign', '--verify', '--deep', '--strict', str(app))
seen = set()
code = []
for path in app.rglob('*'):
    if not path.is_file() or path.is_symlink():
        continue
    real = path.resolve()
    if real in seen:
        continue
    seen.add(real)
    if 'Mach-O' not in run('file', '-b', str(real)):
        continue
    signature = run('codesign', '-dvv', str(real))
    run('codesign', '--verify', '--strict', str(real))
    assert 'TeamIdentifier=S898B9KBWN' in signature, path
    assert 'runtime' in signature, path
    arch = run('lipo', '-archs', str(real)).strip()
    assert set(arch.split()) == {'arm64', 'x86_64'}, (path, arch)
    code.append({'path': str(path.relative_to(app)), 'architectures': arch,
                 'team': 'S898B9KBWN', 'signature': 'PASS', 'hardened_runtime': 'PASS'})
assert any('/Sparkle.framework/' in '/' + x['path'] for x in code)
symlinks = []
for path in app.rglob('*'):
    if path.is_symlink():
        assert path.exists(), path
        assert path.resolve().is_relative_to(app), path
        symlinks.append(str(path.relative_to(app)))
print(json.dumps({'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
                  'bundle_id': info['CFBundleIdentifier'], 'feed': info['SUFeedURL'],
                  'public_key': info['SUPublicEDKey'], 'code': code, 'symlinks': symlinks}, indent=2))
