#!/usr/bin/env bash
set -euo pipefail

SING_BOX_VERSION="${SING_BOX_VERSION:-v1.14.4}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$ROOT/.build/sing-box}"
OUT="$ROOT/app/android/app/libs"

need() {
    command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }
}

need git
need go
need java
[ -n "${ANDROID_HOME:-}" ] || { echo "ANDROID_HOME is not set" >&2; exit 1; }
[ -n "${ANDROID_NDK_HOME:-}" ] || { echo "ANDROID_NDK_HOME is not set" >&2; exit 1; }

if ! command -v gomobile >/dev/null 2>&1; then
    echo "installing gomobile"
    go install github.com/sagernet/gomobile/cmd/gomobile@latest
    export PATH="$(go env GOPATH)/bin:$PATH"
fi

mkdir -p "$(dirname "$WORK")" "$OUT"
if [ ! -d "$WORK/.git" ]; then
    git clone --depth 1 --branch "$SING_BOX_VERSION" \
        https://github.com/SagerNet/sing-box.git "$WORK"
fi

cd "$WORK"
go run ./cmd/internal/build_libbox -target android

cp libbox.aar "$OUT/libbox.aar"
echo "built: $OUT/libbox.aar"
sha256sum "$OUT/libbox.aar"
