#!/opt/tigersh-deps-0.1/bin/bash
# Build the janet-lzo native module (.so) on a Tiger PPC host.
#
# Validates the M1.a native-module loader / @loader_path wiring
# without needing jpm install (which depends on os/spawn, M1.b).
#
# Mirrors jpm's canonical macOS native-module link recipe (from
# https://github.com/janet-lang/jpm/blob/master/configs/macos_config.janet):
#
#   :cflags          @["-std=c99"]
#   :dynamic-cflags  @["-fPIC"]
#   :dynamic-lflags  @["-shared" "-undefined" "dynamic_lookup" "-lpthread"]
#
# No -ljanet — janet's native-module loader uses dynamic_lookup, so
# the .so's calls back into the janet core resolve at dlopen time
# from the already-running janet binary.
#
# Env:
#   JANET_PREFIX   — install root of the Janet we link against,
#                    e.g. /opt/janet-1.41.3-dev.
#   LZO_PREFIX     — install root of lzo, e.g. /opt/lzo-2.10.
#   SRC_DIR        — directory containing lzo.c (the rsync'd
#                    janet-lzo checkout).  cwd on entry.
#   OUT            — where to write lzo.so.  Default
#                    $SRC_DIR/build/lzo.so.

set -e -o pipefail

: "${JANET_PREFIX:=/opt/janet-1.41.3-dev}"
: "${LZO_PREFIX:=/opt/lzo-2.10}"
: "${SRC_DIR:?SRC_DIR must be set}"
: "${OUT:=$SRC_DIR/build/lzo.so}"

export PATH=/opt/gcc-4.9.4/bin:$PATH
CC=${CC:-gcc-4.9}

echo "=== build-janet-lzo-remote.sh ==="
echo "    src:         $SRC_DIR"
echo "    out:         $OUT"
echo "    JANET:       $JANET_PREFIX"
echo "    LZO:         $LZO_PREFIX"
echo "    CC:          $($CC --version | head -1)"
echo

cd "$SRC_DIR"
mkdir -p "$(dirname "$OUT")"

# jpm's macos defaults, applied directly.
CFLAGS=(-std=c99 -Wall -Wextra -Os -fPIC)
CPPFLAGS=(-I"$JANET_PREFIX/include/janet" -I"$LZO_PREFIX/include")
LDFLAGS=(-shared -undefined dynamic_lookup -lpthread
         -L"$LZO_PREFIX/lib" -llzo2)

echo "=== compile + link ==="
set -x
"$CC" "${CFLAGS[@]}" "${CPPFLAGS[@]}" "${LDFLAGS[@]}" -o "$OUT" lzo.c
set +x

echo
echo "=== otool -L $(basename "$OUT") ==="
otool -L "$OUT"

echo
echo "=== file $(basename "$OUT") ==="
file "$OUT"

echo
echo "=== staged smoke (against $JANET_PREFIX) ==="
# Drop the .so into the syspath momentarily for a self-test on this
# host.  Use a writable temp syspath via JANET_PATH instead of
# touching /opt to avoid sudo and to keep the build host clean.
# Tiger's mktemp requires a template; can't pass plain -d.
SMOKE_DIR="$(mktemp -d -t janet-lzo-smoke.XXXXXX)"
trap 'rm -rf "$SMOKE_DIR"' EXIT
cp "$OUT" "$SMOKE_DIR/lzo.so"
JANET_PATH="$SMOKE_DIR" "$JANET_PREFIX/bin/janet" -e '
(import lzo)
(def msg @"hello from janet-lzo on tiger ppc")
(def c (lzo/compress msg))
(def d (lzo/decompress c))
(print "compressed bytes:   " (length c))
(print "decompressed bytes: " (length d))
(print "round-trip ok:      " (= (string msg) (string d)))
'

echo
echo "=== done ==="
