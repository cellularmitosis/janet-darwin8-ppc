#!/opt/tigersh-deps-0.1/bin/bash
# Build janet on a Tiger PPC host and stage a tarball.
#
# Driven by scripts/build-tiger.sh on uranium.  Reads env:
#   PREFIX                  — install prefix inside the tarball, e.g.
#                             /opt/janet-1.41.3
#   JANET_VERSION           — e.g. 1.41.3
#   TARBALL                 — output filename, e.g.
#                             janet-1.41.3-tiger-g3.tar.gz
#   LEGACY_SUPPORT_PREFIX   — where macports-legacy-support is on the
#                             build host
#   REMOTE_DIR              — absolute or $HOME-relative path containing
#                             the rsync'd janet source.  cwd on entry.
#
# Toolchain assumed at fixed /opt paths (gcc-4.9.4, make-4.3,
# ld64-97.17-tigerbrew).  Native build, not cross.

set -e -o pipefail

# tigersh-deps bash is 3.2; safe to use set -o pipefail.

: "${PREFIX:?PREFIX must be set}"
: "${JANET_VERSION:?JANET_VERSION must be set}"
: "${TARBALL:?TARBALL must be set}"
: "${LEGACY_SUPPORT_PREFIX:?LEGACY_SUPPORT_PREFIX must be set}"
: "${REMOTE_DIR:?REMOTE_DIR must be set}"

SRC_DIR="$HOME/$REMOTE_DIR"
STAGE_DIR="$HOME/tmp/janet-staging-$JANET_VERSION"
TARBALL_DIR="$HOME/$REMOTE_DIR"

echo "=== build-tiger-remote.sh ==="
echo "    src:    $SRC_DIR"
echo "    stage:  $STAGE_DIR"
echo "    prefix: $PREFIX"
echo

export PATH=/opt/gcc-4.9.4/bin:/opt/make-4.3/bin:/opt/ld64-97.17-tigerbrew/bin:$PATH
export CC=gcc-4.9
export CPPFLAGS="-I$LEGACY_SUPPORT_PREFIX/include/LegacySupport"
export LDFLAGS="-L$LEGACY_SUPPORT_PREFIX/lib -lMacportsLegacySupport"

cd "$SRC_DIR"

echo "=== compiler ==="
$CC --version | head -1

echo "=== make clean ==="
make clean

echo "=== make ==="
make PREFIX="$PREFIX" -j1

echo "=== make install (DESTDIR=$STAGE_DIR) ==="
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
# Janet's install runs ldconfig on the final $LIBDIR; the rule guards
# it with `[ -z '$(DESTDIR)' ] && $(LDCONFIG)`, so passing DESTDIR
# automatically skips ldconfig (irrelevant on Darwin anyway).
make PREFIX="$PREFIX" DESTDIR="$STAGE_DIR" install

# Bundle macports-legacy-support so the install tree is self-contained
# beyond gcc-libs-4.9.4.
echo "=== bundle libMacportsLegacySupport.dylib ==="
LSS_SRC="$LEGACY_SUPPORT_PREFIX/lib/libMacportsLegacySupport.dylib"
LSS_DST="$STAGE_DIR$PREFIX/lib/libMacportsLegacySupport.dylib"
cp "$LSS_SRC" "$LSS_DST"
chmod u+w "$LSS_DST"

echo "=== install_name_tool wiring ==="
# 1. Self-id the bundled legacy-support dylib to @loader_path/...
install_name_tool -id \
    "@loader_path/libMacportsLegacySupport.dylib" \
    "$LSS_DST"

# 2. Find the staged janet binary and the real libjanet file (the
#    one the install_name_tool changes apply to — the symlinks
#    follow automatically).
JANET_BIN="$STAGE_DIR$PREFIX/bin/janet"
# Pick the only real libjanet.*.dylib (not a symlink).
JANET_DYLIB=
for f in "$STAGE_DIR$PREFIX/lib/"libjanet.*.dylib; do
    if [ -f "$f" ] && [ ! -L "$f" ]; then JANET_DYLIB="$f"; break; fi
done
test -f "$JANET_BIN" || { echo "missing $JANET_BIN" >&2; exit 1; }
test -n "$JANET_DYLIB" || { echo "could not locate real libjanet dylib in $STAGE_DIR$PREFIX/lib/" >&2; ls -la "$STAGE_DIR$PREFIX/lib/" >&2; exit 1; }

# 3. Repoint bin/janet's libMacportsLegacySupport reference to
#    @loader_path/../lib/libMacportsLegacySupport.dylib.  (bin/janet
#    is statically linked against the janet core — it does NOT
#    depend on libjanet.dylib — so only the legacy-support ref
#    needs rewriting.)
install_name_tool -change \
    "$LSS_SRC" \
    "@loader_path/../lib/libMacportsLegacySupport.dylib" \
    "$JANET_BIN"

# 4. Repoint libjanet.*.dylib's own libMacportsLegacySupport ref
#    to a sibling @loader_path entry.  -change is a no-op if the
#    dep wasn't recorded.
install_name_tool -change \
    "$LSS_SRC" \
    "@loader_path/libMacportsLegacySupport.dylib" \
    "$JANET_DYLIB"

# 5. Self-id libjanet.*.dylib to @loader_path/<soname> so native
#    modules built against it find it via @loader_path.  Use the
#    SONAME-style basename (libjanet.MAJ.MIN.dylib) since that's
#    what janet's Makefile records via -install_name.
JANET_DYLIB_SONAME="$(otool -D "$JANET_DYLIB" | tail -1 | xargs basename)"
install_name_tool -id \
    "@loader_path/$JANET_DYLIB_SONAME" \
    "$JANET_DYLIB"

echo "=== otool -L bin/janet ==="
otool -L "$JANET_BIN"
echo "=== otool -L lib/libjanet.*.dylib ==="
otool -L "$JANET_DYLIB"
echo "=== otool -L lib/libMacportsLegacySupport.dylib ==="
otool -L "$LSS_DST"

# 6. Smoke test the staged binary (it should run from its stage path
#    via @loader_path resolution).
echo "=== smoke (staged) ==="
"$JANET_BIN" -e "(print \"hello from janet \" janet/version \" on tiger ppc\")"

# 7. tar.gz the stage.  -C into $STAGE_DIR/opt so the tarball entries
#    start at janet-X.Y.Z/... (not opt/janet-X.Y.Z/...) — caller does
#    `cd /opt && curl ... | tar xz`.
echo "=== tar ==="
TARBALL_PATH="$TARBALL_DIR/$TARBALL"
rm -f "$TARBALL_PATH"
(cd "$STAGE_DIR$(dirname "$PREFIX")" && tar -czf "$TARBALL_PATH" "$(basename "$PREFIX")")
ls -la "$TARBALL_PATH"

echo
echo "=== done ==="
