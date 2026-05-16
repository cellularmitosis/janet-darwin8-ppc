# Session 001 findings

Cross-session-relevant things learned.  Per-session narrative is in
[`README.md`](README.md).

## On Tiger, `_POSIX_C_SOURCE` / `_XOPEN_SOURCE` hide BSD socket types

Tiger's `<sys/cdefs.h>` treats `_POSIX_C_SOURCE`, `_XOPEN_SOURCE`,
`__LP64__`, and `_APPLE_C_SOURCE` as **mutually exclusive** with
`_NONSTD_SOURCE`.  Defining any of the first four puts the headers
into "POSIX subset" mode, hiding BSD extensions like `struct
ip_mreq`, `struct ipv6_mreq`, and the `IP_ADD_MEMBERSHIP` /
`IP_DROP_MEMBERSHIP` socket option macros.

`-D_DARWIN_C_SOURCE` (the modern macOS escape hatch) is **not
honored** by Tiger's headers — that macro postdates 10.4.

Implication for any C codebase being brought up on Tiger: audit
feature-test macros in your headers.  If you define
`_POSIX_C_SOURCE` or `_XOPEN_SOURCE`, you'll lose access to BSD
networking types.  Either skip those defines on Tiger, or rewrite
the affected code to not need the BSD types.

Tiger version detection via `<AvailabilityMacros.h>`:
`!defined(MAC_OS_X_VERSION_10_5)` is true iff building against the
10.4 SDK or earlier.

This finding is captured concretely in patch 0001
([`patches/0001-features.h-skip-_POSIX_C_SOURCE-_XOPEN_SOURCE-on-pre.patch`](../../../patches/0001-features.h-skip-_POSIX_C_SOURCE-_XOPEN_SOURCE-on-pre.patch)).

## macports-legacy-support does NOT provide `<spawn.h>`

Despite shipping `sys/spawn.h`, macports-legacy-support 20221029
does **not** provide a top-level `<spawn.h>` or `posix_spawn{,p}`
implementation on Tiger.  The two are different — macOS programs
use `<spawn.h>`, not `<sys/spawn.h>`.

This confirms the project plan: providing a `posix_spawn` fallback
is genuinely our problem to solve, not something the legacy lib
hides for us.

## ibookg38 fleet inventory

Already installed under `/opt/` (no need to `tiger.sh` these):

```
autoconf-2.71, autogen-5.18.16, automake-1.16.5,
ca-certificates-{20221011,20230110}, cctools-667.3,
clang-8.0.1-ppc-darwin8, cloog-0.18.1, cmake-3.9.6,
curl-7.87.0, expat-2.5.0, gc-8.2.2, gcc-{4.2,4.9.4},
gcc-libs-4.9.4, gcc14, gdbm-1.23, gettext-0.20, gmp-4.3.2,
guile-2.0.14, isl-0.12.2, ld64-97.17-tigerbrew, libffi-3.4.2,
libiconv{,-bootstrap}-1.16, libressl-3.4.2, libtool-2.4.6,
libunistring-1.0, lz4-1.9.4, lzo-2.10,
macports-legacy-support-20221029, make-4.3, tigersh-deps-0.1, …
```

Notably present: `lzo-2.10` for the janet-lzo native-module gate,
`clang-8.0.1-ppc-darwin8` (in case we ever want to try clang
instead of gcc-4.9 for any specific TU), `cmake-3.9.6` (jpm uses
make, not cmake, but worth knowing).

## Janet build env that gets the build started

```
PATH=/opt/gcc-4.9.4/bin:/opt/make-4.3/bin:/opt/ld64-97.17-tigerbrew/bin:$PATH
CC=gcc-4.9
CPPFLAGS=-I/opt/macports-legacy-support-20221029/include/LegacySupport
LDFLAGS=-L/opt/macports-legacy-support-20221029/lib -lMacportsLegacySupport
```

This is the M1.a baseline.  Promote to `scripts/build-tiger.sh`
in session 002.

## Janet upstream's `os/spawn` is wholly posix_spawn-based

`src/core/os.c` lines 62 + 1388–1439 unconditionally use the
`posix_spawn_file_actions_*` family + `posix_spawn`/`posix_spawnp`
for the `os/spawn` implementation.  There is **no** existing
fork+execve fallback path in the upstream code, and **no**
configuration flag to disable `os/spawn` (unlike, say,
`JANET_NO_NET`).

So either (a) M1.b's patch introduces a fallback path that's chosen
at compile time, OR (b) M1.a's stub introduces a flag like
`JANET_NO_PROCESSES` that surrounds the entire `os/spawn` machinery
and the registration call.  (b) is the minimum-change-to-build
path; (a) is the real fix.

## Workflow note: `tiger-rsync.sh` works fine for source trees

`~/bin/tiger-rsync.sh --exclude=...` (which uses `rsync
--protocol=27 --no-dirs -rlptgoDv`) handles the ~2.3 MB janet
source tree in well under a second.  This is the canonical way to
move files between uranium and Tiger boxes; plain modern rsync
will protocol-mismatch.
