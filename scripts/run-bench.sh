#!/bin/bash
# Tiny bench harness for tests/bench.janet.
#
# Runs bench.janet N times against the given janet binary and prints
# the per-workload minimum (best-case = least system noise).  Used in
# session 009 to compare G3 / G4 / G4+AltiVec tarballs on the same
# host.
#
# Usage:
#   scripts/run-bench.sh <janet-bin> <bench.janet> [runs=5]
#
# Output is meant to be tee'd into a session build-log.

set -e
# (intentionally no `set -o pipefail` — Tiger's stock /bin/bash is
# 2.05b which doesn't support it, and this script has no pipelines.)

BIN="${1:?janet binary path}"
BENCH="${2:?bench.janet path}"
RUNS="${3:-5}"

echo "=== run-bench.sh ==="
echo "    bin:    $BIN"
echo "    bench:  $BENCH"
echo "    runs:   $RUNS"
echo "    host:   $(uname -srm)  $(hostname -s 2>/dev/null || true)"
echo

i=1
while [ "$i" -le "$RUNS" ]; do
    echo "--- run $i/$RUNS ---"
    "$BIN" "$BENCH"
    echo
    i=$((i + 1))
done
