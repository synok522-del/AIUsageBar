"""Fail closed on validation bundle metadata, architecture and signing policy."""
import pathlib
import plistlib
import subprocess
import sys

app = pathlib.Path(sys.argv[1])
with (app / 'Contents/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
expected = {
    'CFBundleIdentifier': 'synok522.AIUsageBar.LiveValidation',
    'CFBundleName': 'AIUsageBar Live Validation',
    'CFBundleDisplayName': 'AIUsageBar Live Validation',
    'CFBundleExecutable': 'AIUsageBar Live Validation',
    'CFBundleShortVersionString': '1.1.1',
    'CFBundleVersion': '826',
    'AIUsageBarLiveValidation': True,
    'GitCommit': sys.argv[2],
}
for key, value in expected.items():
    assert info.get(key) == value, f'Unexpected {key}'
assert not any(key.startswith('SU') for key in info), 'Updater metadata forbidden'
assert not info.get('CFBundleURLTypes'), 'URL handlers forbidden'
assert not (app / 'Contents/Library/LoginItems').exists(), 'Login helper forbidden'
executable = app / 'Contents/MacOS' / expected['CFBundleExecutable']
architectures = subprocess.check_output(['lipo', '-archs', str(executable)], text=True).split()
assert set(architectures) == {'arm64', 'x86_64'}, architectures
signature = subprocess.run(['codesign', '-dv', '--verbose=4', str(app)], capture_output=True, text=True, check=True).stderr
assert 'Signature=adhoc' in signature and 'Authority=' not in signature
entitlements = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)], capture_output=True, check=True).stdout
if entitlements.strip():
    rights = plistlib.loads(entitlements)
    assert not rights.get('com.apple.security.app-sandbox')
    assert not rights.get('com.apple.security.application-groups')
    assert not rights.get('keychain-access-groups')
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
print('PASS: isolated metadata, universal binary, ad-hoc signing and entitlements')
