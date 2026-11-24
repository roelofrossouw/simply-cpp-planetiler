#!/usr/bin/env python3
# Copies planetiler.jar's licence and notice files (its own LICENSE and NOTICE.md, and those its
# bundled libraries carry) into a folder, keeping their paths in the jar.
# Usage: extract-notices.py <planetiler.jar> <folder>
import re
import sys
import zipfile
from pathlib import Path

jar, out = sys.argv[1], Path(sys.argv[2])
pattern = re.compile(r'(LICEN[SC]E|NOTICE|COPYING)[^/]*$', re.IGNORECASE)
with zipfile.ZipFile(jar) as archive:
    for name in archive.namelist():
        if name.endswith('/') or not pattern.search(name):
            continue
        target = (out / name).resolve()
        if not str(target).startswith(str(out.resolve()) + '/'):
            continue  # no path outside the folder
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(archive.read(name))
