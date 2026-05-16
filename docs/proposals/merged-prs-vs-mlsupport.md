# Merged upstream Janet PRs vs macports-legacy-support coverage

Audit of the user's previously-merged portability PRs in upstream
`janet-lang/janet`, mapping each against what
[macports-legacy-support](https://github.com/macports/macports-legacy-support)
provides on Mac OS X 10.4 Tiger, to identify candidates for upstream
simplification follow-ups now that macports-legacy-support is part
of the picture.

> **TL;DR — none of the merged PRs should be simplified or
> reverted upstream.**  The initial audit (preserved below) flagged
> PR #937 (Mach `clock_get_time` shim) as redundant under
> mlsupport.  Empirical verification on real Tiger hardware
> (ibookg38, this session) showed it isn't — mlsupport's
> `clock_gettime` shim only covers `CLOCK_REALTIME` and
> `CLOCK_MONOTONIC`, not `CLOCK_PROCESS_CPUTIME_ID`, which Janet's
> POSIX `clock_gettime` path requires.  See the
> [Empirical correction](#empirical-correction) section.

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

**Initial verdict (later overturned):** ✅ "The real win" — when
linked against mlsupport, the Mach branch appeared to be dead code
shadowing a perfectly good libc function.  Filing as an upstream
simplification (gate flip from version-check to feature-check)
looked clean.

**Empirically:** ❌ The "win" doesn't materialize.  See the
[Empirical correction](#empirical-correction) section below for
the full story.  Short version: mlsupport's `clock_gettime` shim
covers only `CLOCK_REALTIME` and `CLOCK_MONOTONIC`; it does *not*
provide `CLOCK_PROCESS_CPUTIME_ID`, which Janet's POSIX path uses
for `JANET_TIME_CPUTIME`.  The Mach branch handles CPUTIME via
`clock()` precisely because that gap exists.  PR #937 is correctly
written; the Mach implementation earns its keep.

## Summary

| PR | Verdict | Action |
|---|---|---|
| #432 (O_CLOEXEC) | Compiles via mlsupport's `O_CLOEXEC=0` shim, but the shim weakens semantics.  PR earns its keep. | Leave alone |
| #436 (arc4random_buf) | mlsupport doesn't cover `arc4random_buf`; fallback still needed. | Leave alone |
| `f06e9ae3` (/dev/urandom) | Implements #436's fallback; still needed. | Leave alone |
| #937 (Mach clock shim) | **Earns its keep** — mlsupport's `clock_gettime` doesn't cover `CLOCK_PROCESS_CPUTIME_ID`, which Janet's POSIX path needs.  The Mach branch's `clock()` fallback handles CPUTIME correctly.  See [Empirical correction](#empirical-correction). | Leave alone |

**Final verdict:** None of the four merged PRs should be simplified
or reverted upstream as a result of mlsupport being available.
Each earns its keep — either for non-mlsupport builders (#432,
#436, `f06e9ae3`) or because mlsupport's own shim is incomplete
(#937).

## Empirical correction

The initial audit (sections above) flagged PR #937 as redundant on
Tiger+mlsupport, with the recommendation to file an upstream
simplification PR replacing the `MAC_OS_X_VERSION_10_12` gate with
a feature-detect.  A prototype landed briefly as `patches/0006`
(`JANET_NO_MACH_CLOCK_SHIM` opt-out flag).

When the flag was wired into `scripts/build-tiger-remote.sh` and
the build was run on ibookg38, it failed at compile time:

```
src/core/util.c:1040:15: error: 'CLOCK_PROCESS_CPUTIME_ID' undeclared
make: *** [Makefile:200: build/core/util.boot.o] Error 1
```

Reading mlsupport's `time.h` (at
`/opt/macports-legacy-support-20221029/include/LegacySupport/time.h`
on ibookg38) confirms why:

```c
#if !defined(CLOCK_REALTIME) && !defined(CLOCK_MONOTONIC)
#define CLOCK_REALTIME  0
#define CLOCK_MONOTONIC 6
typedef int clockid_t;
extern int clock_gettime( clockid_t clk_id, struct timespec *ts );
extern int clock_getres ( clockid_t clk_id, struct timespec *ts );
#endif
```

Only `CLOCK_REALTIME` and `CLOCK_MONOTONIC` are defined.
`CLOCK_PROCESS_CPUTIME_ID` is not provided.

Janet's POSIX `clock_gettime` path
([`src/core/util.c:1029-1039`](https://github.com/janet-lang/janet/blob/master/src/core/util.c))
uses all three:

```c
if (source == JANET_TIME_REALTIME) {
    cid = CLOCK_REALTIME;
} else if (source == JANET_TIME_MONOTONIC) {
    cid = CLOCK_MONOTONIC;
} else if (source == JANET_TIME_CPUTIME) {
    cid = CLOCK_PROCESS_CPUTIME_ID;   // ← unavailable under mlsupport
}
return clock_gettime(cid, spec);
```

The Mach branch (the one PR #937 wraps), in contrast, handles
CPUTIME with a separate libc-`clock()` path that's available on
Tiger:

```c
if (source == JANET_TIME_CPUTIME) {
    clock_t tmp = clock();
    spec->tv_sec = tmp / CLOCKS_PER_SEC;
    spec->tv_nsec = ((tmp - (spec->tv_sec * CLOCKS_PER_SEC)) * 1000000000) / CLOCKS_PER_SEC;
} else {
    // mach_host_self / clock_get_time
}
```

So the Mach branch isn't just doing what mlsupport does badly —
it's covering a clockid mlsupport doesn't expose.  The "dead code"
framing was wrong.  Patch 0006 (and the build-tiger-remote.sh wire-
in) were reverted.  PR #937 stands as-merged.

## Possible follow-up (not pursued here)

If `CLOCK_PROCESS_CPUTIME_ID` were added to mlsupport's
`time.h` — backed by the same `clock()` implementation Janet's
Mach branch uses — then the "feature-check gate" simplification
would become viable.  That's an upstream mlsupport conversation,
not a Janet conversation, and is out of scope for this project.

## Local patches stack is separate

None of the merged PRs analyzed here are in our `patches/`
directory — they are already in upstream.  So there is nothing in
our local delta to "remove" as a result of this audit, and the
single local addition that was attempted (`patches/0006`) has been
reverted.  Net change to `patches/` from this audit: zero.
