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
#   BYO_MACPORTS_LEGACY     — when non-empty, skip bundling the
#                             legacy-support dylib + skip rewriting
#                             install_names to @loader_path.  The
#                             resulting binary keeps the absolute
#                             install_name from
#                             $LEGACY_SUPPORT_PREFIX/lib/, so runtime
#                             requires that dep at the same path.
#   CFLAGS_EXTRA            — optional extra C flags appended to the
#                             default "-O2 -g".  Used for the M2 G4
#                             tarballs (e.g. "-mcpu=7450" or
#                             "-mcpu=7450 -maltivec -mabi=altivec")
#                             and the M3 ppc64 tarball ("-m64").
#                             Only affects the final BUILD_CFLAGS in
#                             Janet's Makefile (bin/janet +
#                             libjanet.dylib + native modules).  The
#                             bootstrap binary `janet_boot` uses
#                             BOOT_CFLAGS which is independent of
#                             CFLAGS, so it stays generic-PPC even
#                             under a -mcpu=7450 build — that's fine
#                             because janet_boot only runs on the
#                             build host during the build.  Same
#                             principle for ppc64: janet_boot is
#                             built ppc32 and runs natively on the
#                             G5 build host; only the final binary +
#                             dylib are ppc64.
#   LDFLAGS_EXTRA           — optional extra LD flags appended to the
#                             link line.  Separate from CFLAGS_EXTRA
#                             because CFLAGS doesn't propagate through
#                             Janet's Makefile to LDFLAGS, and -m64
#                             must reach the link step (otherwise the
#                             linker emits a ppc32 object even though
#                             every .o is ppc64).  M3 ppc64 sets this
#                             to "-m64".
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
: "${BYO_MACPORTS_LEGACY:=}"
: "${CFLAGS_EXTRA:=}"
: "${LDFLAGS_EXTRA:=}"

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
# Janet's Makefile uses `CFLAGS?=-O2 -g` so an exported CFLAGS wins;
# we keep the upstream default and tack on CFLAGS_EXTRA (e.g.
# -mcpu=7450 for G4 builds).  Empty CFLAGS_EXTRA → identical to a G3
# build.
export CFLAGS="-O2 -g $CFLAGS_EXTRA"
LDFLAGS_VAL="-L$LEGACY_SUPPORT_PREFIX/lib -lMacportsLegacySupport"
if [ -z "$BYO_MACPORTS_LEGACY" ]; then
    # Bundled mode: -static-libgcc folds gcc-4.9.4's libgcc helper
    # routines into the binary, so the tarball doesn't carry a runtime
    # dep on /opt/gcc-4.9.4/lib/libgcc_s.1.dylib (i.e. doesn't require
    # tigersh's gcc-libs-4.9.4 package on the host).  Tiger's stock
    # /usr/lib/libgcc_s.1.dylib is still in the link for the ABI
    # baseline -- it's always present on Tiger.
    LDFLAGS_VAL="$LDFLAGS_VAL -static-libgcc"
fi
if [ -n "$LDFLAGS_EXTRA" ]; then
    LDFLAGS_VAL="$LDFLAGS_VAL $LDFLAGS_EXTRA"
fi
export LDFLAGS="$LDFLAGS_VAL"

cd "$SRC_DIR"

echo "=== compiler ==="
$CC --version | head -1
echo "    CFLAGS:  $CFLAGS"
echo "    LDFLAGS: $LDFLAGS"

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

# Locate the staged janet binary + the real libjanet dylib up front;
# both modes (bundled / BYO) need to self-id libjanet so native
# modules find it via @loader_path.
LSS_SRC="$LEGACY_SUPPORT_PREFIX/lib/libMacportsLegacySupport.dylib"
JANET_BIN="$STAGE_DIR$PREFIX/bin/janet"
JANET_DYLIB=
for f in "$STAGE_DIR$PREFIX/lib/"libjanet.*.dylib; do
    if [ -f "$f" ] && [ ! -L "$f" ]; then JANET_DYLIB="$f"; break; fi
done
test -f "$JANET_BIN" || { echo "missing $JANET_BIN" >&2; exit 1; }
test -n "$JANET_DYLIB" || { echo "could not locate real libjanet dylib in $STAGE_DIR$PREFIX/lib/" >&2; ls -la "$STAGE_DIR$PREFIX/lib/" >&2; exit 1; }

if [ -z "$BYO_MACPORTS_LEGACY" ]; then
    # Bundled mode: copy the dylib into the staged tree and rewrite
    # install_names so /opt/janet-X.Y.Z/ is self-contained beyond a
    # normal gcc-libs-4.9.4 dependency.
    echo "=== bundle libMacportsLegacySupport.dylib ==="
    LSS_DST="$STAGE_DIR$PREFIX/lib/libMacportsLegacySupport.dylib"
    cp "$LSS_SRC" "$LSS_DST"
    chmod u+w "$LSS_DST"

    echo "=== install_name_tool wiring (bundled) ==="
    # Self-id the bundled legacy-support dylib to @loader_path/...
    install_name_tool -id \
        "@loader_path/libMacportsLegacySupport.dylib" \
        "$LSS_DST"

    # Repoint bin/janet's libMacportsLegacySupport reference to
    # @loader_path/../lib/libMacportsLegacySupport.dylib.  bin/janet
    # is statically linked against the janet core — it does NOT
    # depend on libjanet.dylib — so only the legacy-support ref
    # needs rewriting.
    install_name_tool -change \
        "$LSS_SRC" \
        "@loader_path/../lib/libMacportsLegacySupport.dylib" \
        "$JANET_BIN"

    # Repoint libjanet.*.dylib's own libMacportsLegacySupport ref
    # to a sibling @loader_path entry.  -change is a no-op if the
    # dep wasn't recorded.
    install_name_tool -change \
        "$LSS_SRC" \
        "@loader_path/libMacportsLegacySupport.dylib" \
        "$JANET_DYLIB"
else
    # BYO mode: leave the absolute LC_LOAD_DYLIB references pointing
    # at $LEGACY_SUPPORT_PREFIX/lib/libMacportsLegacySupport.dylib.
    # The runtime host must have the dep installed at that same path.
    echo "=== BYO mode: skipping bundle + install_name rewrites for libMacportsLegacySupport.dylib ==="
fi

# Self-id libjanet.*.dylib to @loader_path/<soname> so native
# modules built against it find it via @loader_path.  Use the
# SONAME-style basename (libjanet.MAJ.MIN.dylib) since that's
# what janet's Makefile records via -install_name.  Both modes do
# this — it's about libjanet, not about legacy-support.
JANET_DYLIB_SONAME="$(otool -D "$JANET_DYLIB" | tail -1 | xargs basename)"
install_name_tool -id \
    "@loader_path/$JANET_DYLIB_SONAME" \
    "$JANET_DYLIB"

echo "=== otool -L bin/janet ==="
otool -L "$JANET_BIN"
echo "=== otool -L lib/libjanet.*.dylib ==="
otool -L "$JANET_DYLIB"
if [ -z "$BYO_MACPORTS_LEGACY" ]; then
    echo "=== otool -L lib/libMacportsLegacySupport.dylib ==="
    otool -L "$LSS_DST"
fi

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
