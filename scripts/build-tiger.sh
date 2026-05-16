#!/bin/bash
# Build a Tiger PPC janet tarball.
#
# Runs on uranium.  Orchestrates:
#   1. scripts/fetch-janet.sh             — clone, pin, apply patches
#   2. rsync to the Tiger build host      — default: ibookg38
#   3. ssh build-tiger-remote.sh          — native compile, install_name_tool
#                                            wiring, tarball assembly
#   4. scp the tarball back to releases/
#
# Two build modes (selected via BYO_MACPORTS_LEGACY):
#
#   bundled (default) — macports-legacy-support's dylib is copied
#     into the install tree and its install_name rewritten to use
#     @loader_path so /opt/janet-X.Y.Z/ is self-contained beyond a
#     normal gcc-libs-4.9.4 dependency.
#
#   BYO_MACPORTS_LEGACY=1 — skip the bundling + install_name
#     rewriting; the binary's LC_LOAD_DYLIB entry for
#     libMacportsLegacySupport.dylib stays at its absolute install_name
#     ($LEGACY_SUPPORT_PREFIX/lib/libMacportsLegacySupport.dylib).
#     Runtime requires the dep installed at that same absolute path.
#     Tarball name is suffixed with "-byo" so the artifact is
#     unambiguous.  This is the mode leopard.sh / source-builders use.

set -e -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Defaults.
: "${TIGER_HOST:=ibookg38}"
: "${TIGER_ARCH:=g3}"
: "${REMOTE_DIR:=tmp/janet-build}"
: "${LEGACY_SUPPORT_PREFIX:=/opt/macports-legacy-support-20221029}"
: "${BYO_MACPORTS_LEGACY:=}"
# Extra C flags appended to "-O2 -g".  Default empty (G3 build, no
# tuning beyond gcc's PPC defaults).  M2 G4 builds set
# CFLAGS_EXTRA="-mcpu=7450" (and "-mcpu=7450 -maltivec -mabi=altivec"
# for the AltiVec variant); see TIGER_ARCH presets below.
: "${CFLAGS_EXTRA:=}"
# Optional project-level revision marker appended to the tarball
# basename (NOT to PREFIX or the binary's janet/version, since both
# of those still want to match upstream).  Use when we cut a second
# release at the same pinned upstream SHA so the tarballs don't
# collide on the CDN.  Example: RELEASE_REV=r2 →
#   janet-1.41.3-dev-r2-tiger-g3.tar.gz
: "${RELEASE_REV:=}"

# TIGER_ARCH presets: G3 (default, no tuning), G4 (-mcpu=7450), and
# G4 + AltiVec.  An explicit CFLAGS_EXTRA from the caller wins, so
# we only fill in the preset when the caller left it empty.
if [ -z "$CFLAGS_EXTRA" ]; then
    case "$TIGER_ARCH" in
        g3)         CFLAGS_EXTRA="" ;;
        g4)         CFLAGS_EXTRA="-mcpu=7450" ;;
        # AltiVec preset adds -ftree-vectorize because gcc-4.9 doesn't
        # auto-vectorize at -O2 by default — without it, -maltivec
        # would only matter for hand-written intrinsics (which Janet
        # has none of) and the resulting binary would be byte-identical
        # to the plain -mcpu=7450 build.  -ftree-vectorize lets gcc
        # actually try AltiVec on scalar loops, giving us an honest
        # "AltiVec compiler flags only" benchmark vs. the plain G4
        # build.
        g4-altivec) CFLAGS_EXTRA="-mcpu=7450 -maltivec -mabi=altivec -ftree-vectorize" ;;
        *) ;; # unknown arch — leave CFLAGS_EXTRA empty, caller knows what they're doing
    esac
fi

# Janet version comes from upstream's janetconf.h after patches apply.
# Pull it from the freshly-patched source.
scripts/fetch-janet.sh >/dev/null
# JANET_VERSION includes the "-dev" suffix when upstream's janetconf.h
# carries it (master between releases).  Honest about pre-release; the
# tarball name reflects what `janet -e '(print janet/version)'` reports.
JANET_VERSION="$(awk -F'"' '/^#define JANET_VERSION /{print $2}' \
    external/janet/src/conf/janetconf.h)"

REV_SUFFIX=""
if [ -n "$RELEASE_REV" ]; then
    REV_SUFFIX="-${RELEASE_REV}"
fi

if [ -n "$BYO_MACPORTS_LEGACY" ]; then
    BUILD_MODE="byo"
    TARBALL="janet-${JANET_VERSION}${REV_SUFFIX}-tiger-${TIGER_ARCH}-byo.tar.gz"
else
    BUILD_MODE="bundled"
    TARBALL="janet-${JANET_VERSION}${REV_SUFFIX}-tiger-${TIGER_ARCH}.tar.gz"
fi
PREFIX="/opt/janet-${JANET_VERSION}"

echo "=== build-tiger.sh ==="
echo "    host:        $TIGER_HOST"
echo "    arch:        $TIGER_ARCH"
echo "    cflags+:     ${CFLAGS_EXTRA:-(none)}"
echo "    janet ver:   $JANET_VERSION"
echo "    prefix:      $PREFIX"
echo "    tarball:     $TARBALL"
echo "    mode:        $BUILD_MODE (legacy-support=$LEGACY_SUPPORT_PREFIX)"
echo "    remote dir:  $TIGER_HOST:$REMOTE_DIR"
echo

# Sync the patched source tree.  --delete so we don't keep stale files
# from a prior build if patches removed/renamed something.
echo "=== rsync source ==="
~/bin/tiger-rsync.sh --delete --exclude=.git --exclude=build \
    external/janet/ "$TIGER_HOST:$REMOTE_DIR/"

# Ship the remote build script alongside.
scp scripts/build-tiger-remote.sh "$TIGER_HOST:$REMOTE_DIR/build-tiger-remote.sh" >/dev/null
ssh "$TIGER_HOST" "chmod +x $REMOTE_DIR/build-tiger-remote.sh"

# Run the remote build.  Pass the inputs it needs via env so the
# script itself stays generic.
echo
echo "=== remote build ==="
ssh "$TIGER_HOST" \
    "PREFIX='$PREFIX' \
     JANET_VERSION='$JANET_VERSION' \
     TARBALL='$TARBALL' \
     LEGACY_SUPPORT_PREFIX='$LEGACY_SUPPORT_PREFIX' \
     BYO_MACPORTS_LEGACY='$BYO_MACPORTS_LEGACY' \
     CFLAGS_EXTRA='$CFLAGS_EXTRA' \
     REMOTE_DIR='$REMOTE_DIR' \
     '$REMOTE_DIR/build-tiger-remote.sh'"

# Fetch the tarball.
mkdir -p releases
echo
echo "=== fetch tarball ==="
scp "$TIGER_HOST:$REMOTE_DIR/$TARBALL" "releases/$TARBALL"

echo
echo "=== done ==="
ls -la "releases/$TARBALL"
