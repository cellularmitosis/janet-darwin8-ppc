# Session 001 — bring-up and pin

## Arrival state

Fresh repo.  The scaffolding commit
([`af1058e`](https://github.com/cellularmitosis/janet-darwin8-ppc/commit/af1058e))
laid down `CLAUDE.md`, `docs/plan.md`, `docs/roadmap.md`,
`docs/deferred.md`, `docs/sessions/README.md`, and the dir
`README.md` placeholders for `patches/`, `scripts/`, `tests/`,
`demos/`.  No code, no `external/janet/`, no scripts written yet.

Goal: pin a SHA, write the fetch/regen scripts, populate
`external/janet/`, sync to ibookg38, attempt a first build,
capture whatever breaks.

## Fleet probe

ibookg38 (Tiger 10.4.11, Darwin 8.11.0 PPC) was reachable on the
first try.  Most prerequisites already installed under `/opt`:

- `gcc-4.9.4` + `gcc-libs-4.9.4` (thread-local storage support)
- `make-4.3`
- `ld64-97.17-tigerbrew`
- `macports-legacy-support-20221029`
- `lzo-2.10` (already there — handy for the janet-lzo gate)
- `tigersh-deps-0.1` + `tiger.sh` (for installing anything else)

No git on ibookg38 (expected; git on Tiger is fiddly).  Workflow
implication: we manage patches via git on uranium and rsync the
patched source tree to ibookg38 for the actual build.

## Pinned SHA

```
4413d43b7aa79689162c1f143b1c4ce6781b816d
```

`master` HEAD of `janet-lang/janet` as of 2026-05-15 16:18 UTC,
captured via `git ls-remote https://github.com/janet-lang/janet
refs/heads/master`.  Recorded in
[`docs/janet-pin.sha`](../../janet-pin.sha).

Commit message at the pin: "Fix stale fiber stack pointers across
realloc (#1751)".

## What happened

### 1. Scripts: fetch and regen

Wrote two scripts on uranium:

- [`scripts/fetch-janet.sh`](../../../scripts/fetch-janet.sh) — clones
  `janet-lang/janet` into `external/janet/`, checks out the pinned
  SHA, creates a `darwin-ppc` branch, applies any patches from
  `patches/` via `git am`.  Idempotent.
- [`scripts/regen-patches.sh`](../../../scripts/regen-patches.sh) —
  rebuilds `patches/` from `external/janet/`'s `darwin-ppc` branch
  via `git format-patch`.  Guards against running on the wrong
  branch or before the SHA has been pinned.

`fetch-janet.sh` cloned cleanly and produced `external/janet/` at
the pinned SHA on the `darwin-ppc` branch, with zero patches.

### 2. First build attempt — vanilla make + macports-legacy-support

Rsync'd source to `ibookg38:tmp/janet/` via `~/bin/tiger-rsync.sh`
(2.3 MB), then on the Tiger box:

```
export PATH="/opt/gcc-4.9.4/bin:/opt/make-4.3/bin:/opt/ld64-97.17-tigerbrew/bin:$PATH"
export CC=gcc-4.9
export CPPFLAGS="-I/opt/macports-legacy-support-20221029/include/LegacySupport"
export LDFLAGS="-L/opt/macports-legacy-support-20221029/lib -lMacportsLegacySupport"
make
```

Compilation got most of the way through `src/core/*.c` then died at
`net.c:1175`:

```
src/core/net.c:1175:24: error: field 'v_mreq' has incomplete type
         struct ip_mreq v_mreq;
                        ^
```

Plus a dozen similar errors all involving `struct ip_mreq` and
`struct ipv6_mreq` (the IPv4/IPv6 multicast setsockopt code).  Full
log: [`build-logs/build1-vanilla-make.log`](build-logs/build1-vanilla-make.log).

### 3. Diagnosis: `_POSIX_C_SOURCE` hides BSD socket types on Tiger

`struct ip_mreq` *is* defined in Tiger's `<netinet/in.h>` — but
gated behind `#ifndef _POSIX_C_SOURCE`.  Tiger's `<sys/cdefs.h>`
treats `_POSIX_C_SOURCE`, `_XOPEN_SOURCE`, `__LP64__`, and
`_APPLE_C_SOURCE` as mutually exclusive with `_NONSTD_SOURCE` —
defining any of them puts the headers into "POSIX subset" mode
and hides BSD extensions.

Empirical test on the Tiger box, with `gcc-4.9 -std=c99` against a
minimal `<netinet/in.h>` consumer:

| Defines | ip_mreq visible? |
|---|---|
| (none) | ✅ yes |
| `-D_POSIX_C_SOURCE=200809L` | ❌ no |
| `-D_XOPEN_SOURCE=600` | ❌ no |
| `-D_BSD_SOURCE` | ✅ yes |
| `-D_BSD_SOURCE -D_DARWIN_C_SOURCE` | ✅ yes |

`-D_DARWIN_C_SOURCE` (which modern macOS uses to un-hide BSD types
when `_POSIX_C_SOURCE` is set) is **not honored** by Tiger's
headers — Tiger predates that macro.

Janet's `src/core/features.h` unconditionally sets `_BSD_SOURCE`,
`_POSIX_C_SOURCE 200809L`, `_DARWIN_C_SOURCE`, and `_XOPEN_SOURCE
600` on Apple.  On modern macOS that works; on Tiger, the POSIX/
XOPEN macros override the BSD intent.

### 4. Patch 0001 — features.h pre-Leopard guard

Wrote a small patch to `src/core/features.h` that:

1. Includes `<AvailabilityMacros.h>` early to get
   `MAC_OS_X_VERSION_10_5`.
2. Defines a private `JANET_APPLE_PRE_LEOPARD` macro when
   `!defined(MAC_OS_X_VERSION_10_5)`.
3. Guards the `_POSIX_C_SOURCE 200809L` and `_XOPEN_SOURCE 600`
   defines with `#ifndef JANET_APPLE_PRE_LEOPARD`.

`_BSD_SOURCE` and `_DARWIN_C_SOURCE` are still set on Tiger — they
don't restrict the headers.

Committed to `external/janet/` on the `darwin-ppc` branch as
`6425a0b4` and regenerated as
[`patches/0001-features.h-skip-_POSIX_C_SOURCE-_XOPEN_SOURCE-on-pre.patch`](../../../patches/0001-features.h-skip-_POSIX_C_SOURCE-_XOPEN_SOURCE-on-pre.patch).

Upstreamable in shape: small, well-motivated, only kicks in on
pre-10.5 Apple, no Tiger-specific paths.  Eventually goes upstream
as a janet-lang/janet PR.

### 5. Second build attempt — features.h patched

Rsync'd the patched `features.h`, ran `make clean && make`.  Got
past `net.c` cleanly.  Hit the expected next blocker:

```
src/core/os.c:62:19: fatal error: spawn.h: No such file or directory
 #include <spawn.h>
                   ^
```

Tiger lacks `<spawn.h>`.  macports-legacy-support has a
`sys/spawn.h` but **not** a top-level `<spawn.h>`, so it doesn't
help.  This is the substantive `posix_spawn` problem we knew was
coming — explicitly an M1.b task per the roadmap.

Full second build log:
[`build-logs/build2-features-h-patched.log`](build-logs/build2-features-h-patched.log).

## Exit state

- Repo scaffolding ✅, fetch + regen scripts ✅, pinned SHA ✅.
- `external/janet/` on `darwin-ppc` branch with one commit on top
  of the pin (patch 0001, features.h).
- `patches/0001-features.h-skip-_POSIX_C_SOURCE-_XOPEN_SOURCE-on-pre.patch`
  is the canonical record.
- Build on ibookg38 gets past `net.c` (the immediate blocker)
  and dies at `<spawn.h>` (the M1.b blocker, expected).
- Tarball not yet built; install_name_tool wiring not yet written.

Next session: stub out posix_spawn for M1.a compile-and-build
(separate from M1.b's "make it actually work"), get the build
through to a working `janet` binary, package as a tarball, and
verify on ibookg37.

See [HANDOFF.md](HANDOFF.md) for the session-002 primer.
