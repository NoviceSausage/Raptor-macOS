#!/usr/bin/env bash
#
# extract-credits.sh — print RAPTOR's own author credits
#
# RAPTOR stores its About-dialog text as separate UTF-16LE runs, not as
# contiguous strings, so `strings` and plain substring searches both miss it.
# This walks the byte stream and prints the runs around the credits block.
#
# Use it to refresh the author list in THIRD-PARTY-NOTICES.md whenever a new
# upstream build is packaged. See docs/RELEASING.md.
#
# Usage: ./tools/extract-credits.sh <path-to-raptor.dll>

set -euo pipefail

DLL="${1:-}"
if [ -z "$DLL" ] || [ ! -f "$DLL" ]; then
    printf 'usage: %s <path-to-raptor.dll>\n' "${0##*/}" >&2
    exit 2
fi

python3 - "$DLL" <<'PY'
import sys

data = open(sys.argv[1], "rb").read()

# Collect printable ASCII runs that are UTF-16LE encoded (char, 0x00).
runs, i, n = [], 0, len(data) - 1
while i < n:
    if 32 <= data[i] <= 126 and data[i + 1] == 0:
        buf, start = bytearray(), i
        while i < n and 32 <= data[i] <= 126 and data[i + 1] == 0:
            buf.append(data[i])
            i += 2
        runs.append((start, buf.decode("ascii")))
    else:
        i += 1

for idx, (_, text) in enumerate(runs):
    if "Avalonia Edition" in text:
        print("--- RAPTOR credits, as embedded in the application ---")
        for off, entry in runs[idx:idx + 24]:
            print(f"  {off:#08x}  {entry}")
        sys.exit(0)

print("credits block not found: is this a RAPTOR Avalonia build?", file=sys.stderr)
sys.exit(1)
PY
