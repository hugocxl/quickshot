#!/bin/bash
# Development-only renderer; the app has no runtime dependencies.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/artwork media
npx --yes --package @resvg/resvg-js-cli@2.6.2-beta.1 resvg-js \
    Quickshot/Quickshot-icon.svg build/artwork/icon.png
python3 - <<'PY'
import json
import subprocess
from pathlib import Path
catalog = Path('Quickshot/Assets.xcassets/AppIcon.appiconset')
for image in json.loads((catalog / 'Contents.json').read_text())['images']:
    size = int(image['size'].split('x')[0]) * int(image['scale'][0])
    subprocess.run(['sips', '-z', str(size), str(size), 'build/artwork/icon.png',
                    '--out', str(catalog / image['filename'])], check=True, stdout=subprocess.DEVNULL)
subprocess.run(['sips', '-z', '512', '512', 'build/artwork/icon.png',
                '--out', 'media/icon.png'], check=True, stdout=subprocess.DEVNULL)
PY
