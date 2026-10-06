#!/usr/bin/env python3
"""Inspect a staging DMG without installing or launching its app."""
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

image = Path(sys.argv[1]).resolve()
canonical = Path(sys.argv[2]).resolve() if len(sys.argv) == 3 else None

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout

def inventory(root):
    result = {}
    for path in root.rglob('*'):
        relative = str(path.relative_to(root))
        if path.is_symlink():
            result[relative] = {'symlink': str(path.readlink())}
        elif path.is_file():
            result[relative] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                                'mode': stat.S_IMODE(path.stat().st_mode)}
    return result

run('codesign', '--verify', '--strict', str(image))
run('xcrun', 'stapler', 'validate', str(image))
run('spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', str(image))
with tempfile.TemporaryDirectory(prefix='AIUsageBar-U1-inspect-') as mount:
    attached = False
    try:
        run('hdiutil', 'attach', str(image), '-readonly', '-nobrowse', '-noautoopen', '-mountpoint', mount)
        attached = True
        root = Path(mount)
        apps = list(root.glob('*.app'))
        assert [p.name for p in apps] == ['AIUsageBar.app']
        assert (root / 'Applications').is_symlink()
        assert str((root / 'Applications').readlink()) == '/Applications'
        app = apps[0]
        details = json.loads(run(sys.executable, str(Path(__file__).with_name('verify-app.py')), str(app)))
        run('xcrun', 'stapler', 'validate', str(app))
        run('spctl', '--assess', '--type', 'execute', str(app))
        if canonical:
            assert inventory(app) == inventory(canonical), 'Packaging changed content, modes or symlinks'
    finally:
        if attached:
            run('hdiutil', 'detach', mount)
print(json.dumps({'image': image.name, 'sha256': hashlib.sha256(image.read_bytes()).hexdigest(),
                  'size': image.stat().st_size, 'app': details, 'canonical_comparison': 'PASS' if canonical else 'NOT_TESTED',
                  'detach': 'PASS'}, indent=2))
