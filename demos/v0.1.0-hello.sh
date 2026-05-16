#!/bin/sh
# v0.1.0-hello.sh — one-command wrapper around v0.1.0-hello.janet.
#
# Runs the v0.1.0 demo against /opt/janet-1.41.3-dev/bin/janet.
# Install the tarball first if you haven't:
#
#   sudo mkdir -p /opt && sudo chmod ugo+rwx /opt && cd /opt
#   curl http://leopard.sh/misc/beta/janet-1.41.3-dev-tiger-g3.tar.gz \
#       | gunzip | tar x
#
# The optional `(import lzo)` block needs janet-lzo's lzo.so dropped
# under /opt/janet-1.41.3-dev/lib/janet/.  Without it the demo skips
# step [4] and otherwise runs to completion.

set -e

JANET=/opt/janet-1.41.3-dev/bin/janet
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT=$HERE/v0.1.0-hello.janet

if [ ! -x "$JANET" ]; then
    echo "$0: $JANET not found." >&2
    echo "Install the v0.1.0 tarball first:" >&2
    echo "  curl http://leopard.sh/misc/beta/janet-1.41.3-dev-tiger-g3.tar.gz \\" >&2
    echo "      | gunzip | (cd /opt && tar x)" >&2
    exit 1
fi

if [ ! -f "$SCRIPT" ]; then
    echo "$0: $SCRIPT not found next to this wrapper." >&2
    exit 1
fi

exec "$JANET" "$SCRIPT"
