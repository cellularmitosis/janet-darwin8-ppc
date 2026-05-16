#!/bin/bash
# Regenerate patches/ from the `darwin-ppc` branch in external/janet/.
# Each commit on darwin-ppc beyond the pinned SHA becomes one patch
# file (NNNN-<slug>.patch via `git format-patch`).
#
# Runs on uranium.  Run this any time you've added/amended a commit
# in external/janet/ that should be part of our delta.

set -e -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SHA="$(cat docs/janet-pin.sha | head -1 | tr -d '[:space:]')"
if [ -z "$SHA" ]; then
    echo "error: docs/janet-pin.sha is empty" >&2
    exit 1
fi

if [ ! -d external/janet/.git ]; then
    echo "error: external/janet/ doesn't exist.  Run scripts/fetch-janet.sh first." >&2
    exit 1
fi

cd external/janet

# Sanity check: we should be on darwin-ppc and the pinned SHA must be
# an ancestor.
current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$current_branch" != "darwin-ppc" ]; then
    echo "error: external/janet/ is on '$current_branch', expected 'darwin-ppc'" >&2
    exit 1
fi
if ! git merge-base --is-ancestor "$SHA" HEAD; then
    echo "error: pinned SHA $SHA is not an ancestor of darwin-ppc HEAD" >&2
    exit 1
fi

cd "$REPO_ROOT"

# Wipe and regenerate.
rm -f patches/[0-9]*.patch
cd external/janet
git format-patch --no-signature "$SHA" -o "$REPO_ROOT/patches/" >/dev/null

cd "$REPO_ROOT"
count=$(find patches -maxdepth 1 -name '[0-9]*.patch' | wc -l | tr -d ' ')
if [ "$count" -eq 0 ]; then
    echo "No patches: darwin-ppc is at the pinned SHA with no extra commits."
else
    echo "Regenerated $count patch(es):"
    ls -1 patches/[0-9]*.patch
fi
