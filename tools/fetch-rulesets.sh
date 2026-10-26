#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/app/assets/rule-sets"
BASE="https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set"

mkdir -p "$OUT"

for name in youtube instagram; do
    echo "fetching geosite-$name.srs"
    curl -fsSL "$BASE/geosite-$name.srs" -o "$OUT/geosite-$name.srs"
done

ls -l "$OUT"
