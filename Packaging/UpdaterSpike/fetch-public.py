#!/usr/bin/env python3
"""Fetch a public staging artifact/feed over HTTPS; record safe response evidence."""
import hashlib
import json
from pathlib import Path
import sys
import urllib.parse
import urllib.request

class HTTPSRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlparse(newurl).scheme != 'https':
            raise ValueError('Refusing non-HTTPS redirect')
        return super().redirect_request(req, fp, code, msg, headers, newurl)

url, output = sys.argv[1:]
assert urllib.parse.urlparse(url).scheme == 'https'
path = Path(output)
assert not path.exists(), 'Use a new path for independently fetched bytes'
path.parent.mkdir(parents=True, exist_ok=True)
opener = urllib.request.build_opener(HTTPSRedirect())
with opener.open(urllib.request.Request(url, headers={'User-Agent': 'AIUsageBar-U1-Audit'}), timeout=120) as response:
    assert response.status == 200
    digest = hashlib.sha256()
    size = 0
    with path.open('xb') as file:
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
            size += len(chunk)
            file.write(chunk)
    headers = {key: response.headers.get(key) for key in
               ('Content-Type', 'Content-Length', 'Cache-Control', 'ETag', 'Last-Modified', 'Age')}
    if headers['Content-Length'] is not None:
        assert int(headers['Content-Length']) == size
    result = {'url': url, 'status': response.status,
              'final_host': urllib.parse.urlparse(response.url).hostname,
              'headers': headers, 'size': size, 'sha256': digest.hexdigest()}
Path(output + '.http.json').write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
