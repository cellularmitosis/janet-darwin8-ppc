# Merged upstream Janet PRs vs macports-legacy-support coverage

Audit of the user's previously-merged portability PRs in upstream
`janet-lang/janet`, mapping each against what
[macports-legacy-support](https://github.com/macports/macports-legacy-support)
provides on Mac OS X 10.4 Tiger, to identify candidates for upstream
simplification follow-ups now that macports-legacy-support is part
of the picture.

**Important caveat up front: "removing" a merged PR upstream is not
actually an option** — once merged, the commit is in upstream
history.  What *is* on the table is **follow-up simplification
PRs** (change a gate, drop a now-dead branch).  Even then,
upstream's frame is "macports-legacy-support is a thing some Tiger
users link" not "every Tiger user has it" — so most of the
workarounds still earn their keep for builders without the shim.

## Inventory of user-authored upstream commits

From `git log --author='Pepas' --oneline` in `external/janet/`,
the merged commits attributable to this user are:

| SHA | Title | Likely PR | Touches |
|---|---|---|---|
| `f9f90ba1` / `5565f02d` | O_CLOEXEC support (+ simplification) | #432 | runtime shim |
| `597d84e2` / `f5d208d5` | arc4random_buf support (+ stack-alloc cleanup) | #436 | runtime shim |
| `f06e9ae3` | /dev/urandom for OS X < 10.7 | — | random fallback |
| `c9986936` | Mac clock shim not needed until 10.12 | #937 | clock_gettime |
| `f270739f` | Refactor `__MACH__` to `JANET_APPLE` | — | cosmetic |
| `ab910d06` | Move AvailabilityMacros.h into util.c | — | reorg |
| `e9870b29` | Remove unneeded includes | — | cosmetic |
| `43139b43` | Produce dylibs on macOS | — | build |
| `a110b103` | `math/nan` | — | unrelated |
| `51bf8a35` | Add ppc to `os/arch` | — | unrelated |

The cosmetic, refactor, and unrelated commits (`f270739f`,
`ab910d06`, `e9870b29`, `43139b43`, `a110b103`, `51bf8a35`) are
orthogonal to macports-legacy-support's coverage and are excluded
from the analysis below.  The four remaining are the runtime
portability workarounds — the ones that might become redundant
once macports-legacy-support is in scope.

## Per-PR mapping (assuming macports-legacy-support is linked)

### PR #432 + `5565f02d` — O_CLOEXEC

**What the PR does:** Provides a fallback when `O_CLOEXEC` is
missing.  Janet's `net.c:110` is gated on
`!defined(SOCK_CLOEXEC) && defined(O_CLOEXEC)`.

**macports-legacy-support coverage:** Provides `#define O_CLOEXEC 0`
in its `<sys/fcntl.h>` interposition header.

**⚠️ Caveat:** This makes the code compile, but semantically
weakens close-on-exec to a no-op.  An fd opened with
`O_RDONLY | O_CLOEXEC` will leak to children if the process later
forks.  Safe for janet's `/dev/urandom` read (fd closed before any
fork can happen), but it is not a "real" shim — applications that
rely on the close-on-exec semantics would be silently broken.

**Verdict:** **Leave the merged PR alone.**  It earns its keep
for any non-mlsupport build.  Not worth a simplification PR.

### PR #436 + `f5d208d5` — arc4random_buf

**What the PR does:** Adds a `/dev/urandom` fallback for systems
without `arc4random_buf`.  Gated on
`defined(JANET_BSD) || defined(MAC_OS_X_VERSION_10_7)` at
`util.c:1059` and `util.c:1076`.

**macports-legacy-support coverage:** Does **not** provide
`arc4random_buf` (BSD-origin, not POSIX — outside mlsupport's
typical scope).  Janet's own fallback path runs on Tiger as
designed.

**Verdict:** Could in principle be simplified to a feature-detect
(`HAVE_ARC4RANDOM_BUF`) instead of a version check, but cosmetic
only.  Not redundant.  Low value as an upstream simplification PR.

### `f06e9ae3` — /dev/urandom for OS X < 10.7

**What the PR does:** Implements the `/dev/urandom` fallback path
used by PR #436 above.  Opens `/dev/urandom` with
`O_RDONLY | O_CLOEXEC`.

**macports-legacy-support coverage:** The path itself is
platform-agnostic; it relies on `O_CLOEXEC`, which mlsupport's
header shim now provides (see #432 caveat above).

**Verdict:** Path still runs and is needed (PR #436 has no other
fallback for Tiger).  Leave alone.  Cosmetic at best.

### PR #937 — Mach `clock_get_time` shim

**What the PR does:** Gates an entire Mach-based `clock_get_time`
implementation of `janet_gettime()` on
`defined(JANET_APPLE) && !defined(MAC_OS_X_VERSION_10_12)` at
`util.c:1003`.  Fires on Tiger because the 10.4 SDK has no 10.12
availability marker.

**macports-legacy-support coverage:** Provides `clock_gettime()`
directly down to Tiger.

**Verdict:** ✅ **The real win.**  When linked against mlsupport,
the entire Mach branch becomes dead code that shadows a perfectly
good libc function.  Upstream could change the gate from a
version-check to a feature-check (e.g. `!HAVE_CLOCK_GETTIME`,
`!_POSIX_TIMERS`, or an opt-out preprocessor flag) while keeping
the Mach implementation as a fallback for the no-mlsupport world.
Already flagged in [`../deferred.md`](../deferred.md) under
"Upstream PRs".

**Prototype:** Shipped as
[`patches/0006-util.c-opt-out-for-Mach-clock_get_time-shim-via-JANE.patch`](../../patches/0006-util.c-opt-out-for-Mach-clock_get_time-shim-via-JANE.patch).
Introduces a `JANET_NO_MACH_CLOCK_SHIM` opt-out flag.  When defined
(via `-DJANET_NO_MACH_CLOCK_SHIM` in `CPPFLAGS`), the `#elif` falls
through to the POSIX `clock_gettime()` branch, which resolves via
mlsupport on Tiger.  No default-behavior change.

## Summary

| PR | Verdict | Action |
|---|---|---|
| #432 (O_CLOEXEC) | Compiles via mlsupport's `O_CLOEXEC=0` shim, but the shim weakens semantics.  PR earns its keep. | Leave alone |
| #436 (arc4random_buf) | mlsupport doesn't cover `arc4random_buf`; fallback still needed. | Leave alone |
| `f06e9ae3` (/dev/urandom) | Implements #436's fallback; still needed. | Leave alone |
| #937 (Mach clock shim) | Dead code under mlsupport; gate could become feature-check. | ✅ Worth a follow-up — prototype = `patches/0006` |

Of the four candidates, only **PR #937** is worth a follow-up
upstream simplification PR.  The other three are debatable cosmetic
wins at best and should probably stay in upstream untouched.

## How to surface upstream

TBD as of writing.  Two paths under consideration:

- **Open an issue first**, point upstream at this document and the
  `patches/` directory, ask how they want to proceed.  Better fit
  for a multi-patch discussion (the `posix_spawn` stack from
  sessions 005–007 also still needs to land), letting the
  maintainer set the shape and cadence.
- **Send a direct PR** for the #937 simplification using
  `patches/0006` as the starting point.  Lower friction for a
  single-patch change, but doesn't establish the larger context
  for the spawn stack.

## Local patches stack is separate

None of the merged PRs analyzed here are in our `patches/`
directory — they are already in upstream.  So there is nothing in
our local delta to "remove" as a result of this audit.  The work,
if any, is upstream simplification PRs.  The single local addition
prompted by this audit is `patches/0006` (the #937 simplification
prototype).
