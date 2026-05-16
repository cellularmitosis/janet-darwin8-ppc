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
# Build mode is "bundled": macports-legacy-support's dylib is copied
# into the install tree and its install_name rewritten to use
# @loader_path so /opt/janet-X.Y.Z/ is self-contained beyond a
# normal gcc-libs-4.9.4 dependency.

set -e -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Defaults.
: "${TIGER_HOST:=ibookg38}"
: "${TIGER_ARCH:=g3}"
: "${REMOTE_DIR:=tmp/janet-build}"
: "${LEGACY_SUPPORT_PREFIX:=/opt/macports-legacy-support-20221029}"

# Janet version comes from upstream's janetconf.h after patches apply.
# Pull it from the freshly-patched source.
scripts/fetch-janet.sh >/dev/null
# JANET_VERSION includes the "-dev" suffix when upstream's janetconf.h
# carries it (master between releases).  Honest about pre-release; the
# tarball name reflects what `janet -e '(print janet/version)'` reports.
JANET_VERSION="$(awk -F'"' '/^#define JANET_VERSION /{print $2}' \
    external/janet/src/conf/janetconf.h)"

TARBALL="janet-${JANET_VERSION}-tiger-${TIGER_ARCH}.tar.gz"
PREFIX="/opt/janet-${JANET_VERSION}"

echo "=== build-tiger.sh ==="
echo "    host:        $TIGER_HOST"
echo "    arch:        $TIGER_ARCH"
echo "    janet ver:   $JANET_VERSION"
echo "    prefix:      $PREFIX"
echo "    tarball:     $TARBALL"
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
