#!/bin/bash
# Clone janet-lang/janet into external/janet/, check out the pinned
# SHA, create a `darwin-ppc` branch, and apply patches from
# `patches/` on top.  Idempotent: re-running resets the working
# branch back to the pinned SHA and re-applies patches cleanly.
#
# Runs on uranium (or any dev host with git).  The Tiger build host
# (ibookg38) doesn't get a clone — we rsync the patched tree to it.

set -e -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SHA="$(cat docs/janet-pin.sha | head -1 | tr -d '[:space:]')"
if [ -z "$SHA" ]; then
    echo "error: docs/janet-pin.sha is empty" >&2
    exit 1
fi

if [ ! -d external/janet/.git ]; then
    mkdir -p external
    git clone https://github.com/janet-lang/janet external/janet
fi

cd external/janet

# Make sure we have the pinned SHA locally.
if ! git cat-file -e "$SHA^{commit}" 2>/dev/null; then
    git fetch origin
fi
if ! git cat-file -e "$SHA^{commit}" 2>/dev/null; then
    echo "error: SHA $SHA not found after fetch" >&2
    exit 1
fi

# Reset the working branch to the pinned SHA.
git checkout -q "$SHA"
git switch -q -C darwin-ppc

# Apply patches in numeric order, if any.
shopt -s nullglob
patches=("$REPO_ROOT"/patches/[0-9]*.patch)
shopt -u nullglob

if [ "${#patches[@]}" -gt 0 ]; then
    echo "Applying ${#patches[@]} patch(es)..."
    git -c user.name='janet-darwin8-ppc' \
        -c user.email='janet-darwin8-ppc@local' \
        am "${patches[@]}"
else
    echo "No patches to apply."
fi

echo
echo "external/janet/ is now at:"
git log --oneline -n 5
