#!/bin/sh
# v0.2.0-jpm-install-lzo.sh — one-command M1.b acceptance demo.
#
# On a vanilla Tiger PPC box (G3 / G4 / G5) with tigersh installed:
#
#   1. Installs the prerequisites via tigersh
#      (gcc-libs-4.9.4, macports-legacy-support-20221029, git-2.35.1,
#      lzo-2.10, gcc-4.9.4, make-4.3).
#   2. Curls + unpacks the v0.2.0 janet tarball under /opt.
#   3. Bootstraps jpm against the freshly installed janet, using a
#      Tiger-specific jpm config baked into this script.
#   4. `jpm install https://github.com/cellularmitosis/janet-lzo`.
#   5. Runs v0.2.0-jpm-install-lzo.janet — which os/spawn-round-trips
#      and then lzo-round-trips through the installed module.
#
# This is the gate for M1.b: every step rides on the posix_spawn
# fork+execve fallback that landed in session 006.

set -e

JANET_VER=1.41.3-dev
JANET_REV=r2
JANET_PREFIX=/opt/janet-${JANET_VER}
TARBALL=janet-${JANET_VER}-${JANET_REV}-tiger-g3.tar.gz
TARBALL_URL=http://leopard.sh/misc/beta/${TARBALL}

JANET=${JANET_PREFIX}/bin/janet
JPM=${JANET_PREFIX}/bin/jpm

LEGACY_SUPPORT_PREFIX=/opt/macports-legacy-support-20221029
LZO_PREFIX=/opt/lzo-2.10

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT=$HERE/v0.2.0-jpm-install-lzo.janet

# --- 1. prerequisites via tigersh ---------------------------------------------

if ! type -p tiger.sh >/dev/null 2>&1; then
    echo "$0: tiger.sh not found — install it from https://leopard.sh first." >&2
    exit 1
fi

for pkg in gcc-libs-4.9.4 macports-legacy-support-20221029 \
           gcc-4.9.4 make-4.3 ld64-97.17-tigerbrew \
           git-2.35.1 lzo-2.10; do
    if [ ! -d /opt/$pkg ]; then
        echo "=== tiger.sh $pkg ==="
        tiger.sh $pkg
    fi
done

# Toolchain on PATH for the build phases.
export PATH=/opt/gcc-4.9.4/bin:/opt/make-4.3/bin:/opt/ld64-97.17-tigerbrew/bin:${JANET_PREFIX}/bin:/usr/local/bin:/usr/bin:/bin

# Help gcc find lzo headers + lib without polluting jpm config.
export CPATH=${LZO_PREFIX}/include
export LIBRARY_PATH=${LZO_PREFIX}/lib

# --- 2. curl + install the janet tarball --------------------------------------

if [ ! -x "$JANET" ]; then
    if [ ! -w /opt ]; then
        echo "$0: /opt is not writable.  Run this first:" >&2
        echo "  sudo mkdir -p /opt && sudo chmod ugo+rwx /opt" >&2
        exit 1
    fi
    echo "=== install $TARBALL into /opt ==="
    (cd /opt && curl -fL "$TARBALL_URL" | gunzip | tar x)
fi

"$JANET" -e "(print \"janet \" janet/version \" ready at $JANET\")"

# --- 3. bootstrap jpm if not already installed --------------------------------

if [ ! -x "$JPM" ]; then
    echo "=== bootstrap jpm into $JANET_PREFIX ==="
    JPM_SRC=/tmp/jpm-bootstrap.$$
    rm -rf "$JPM_SRC"
    git clone --depth 1 https://github.com/janet-lang/jpm.git "$JPM_SRC"

    cat > "$JPM_SRC/configs/tiger_ppc_config.janet" << EOF
(def prefix "${JANET_PREFIX}")
(def legacy "${LEGACY_SUPPORT_PREFIX}")
(def config
  {:ar "ar"
   :auto-shebang true
   :binpath (string prefix "/bin")
   :c++ "gcc-4.9"
   :c++-link "gcc-4.9"
   :cc "gcc-4.9"
   :cc-link "gcc-4.9"
   :cflags @["-std=c99" (string "-I" legacy "/include/LegacySupport")]
   :cflags-verbose @["-Wall" "-Wextra"]
   :cppflags @["-std=c++11" (string "-I" legacy "/include/LegacySupport")]
   :curlpath "curl"
   :dynamic-cflags @["-fPIC"]
   :dynamic-lflags @["-shared" "-undefined" "dynamic_lookup" "-lpthread"]
   :gitpath "git"
   :headerpath (string prefix "/include/janet")
   :is-msvc false
   :janet "janet"
   :janet-cflags @[]
   :janet-lflags @["-lm" "-lpthread" (string "-L" legacy "/lib") "-lMacportsLegacySupport"]
   :ldflags @[(string "-L" legacy "/lib")]
   :lflags @["-lMacportsLegacySupport"]
   :libpath (string prefix "/lib")
   :local false
   :manpath (string prefix "/share/man/man1")
   :modext ".so"
   :modpath (string prefix "/lib/janet")
   :nocolor true
   :optimize 2
   :pkglist "https://github.com/janet-lang/pkgs.git"
   :silent false
   :statext ".a"
   :tarpath "tar"
   :test false
   :use-batch-shell false
   :verbose true})
EOF

    (cd "$JPM_SRC" && PREFIX="$JANET_PREFIX" "$JANET" bootstrap.janet configs/tiger_ppc_config.janet)
    rm -rf "$JPM_SRC"
fi

"$JPM" help | head -1

# --- 4. jpm install janet-lzo -------------------------------------------------

if [ ! -f "$JANET_PREFIX/lib/janet/lzo.so" ]; then
    echo "=== jpm install janet-lzo ==="
    "$JPM" install https://github.com/cellularmitosis/janet-lzo.git
fi

# --- 5. run the demo ----------------------------------------------------------

echo "=== run v0.2.0-jpm-install-lzo.janet ==="
exec "$JANET" "$SCRIPT"
