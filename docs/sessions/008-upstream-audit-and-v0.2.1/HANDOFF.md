# HANDOFF — session 008 → 009

## Where things stand

**v0.2.1 is published.**  Bundled tarball is now genuinely standalone
(no `/opt` prereqs) thanks to `-static-libgcc`.  Verified on
ibookg37 with `/opt/gcc-4.9.4` moved aside.  Patch stack is 6:
0001-0005 portability (unchanged from v0.2.0), 0006 adds `:cd`
coverage to upstream's `test/suite-os.janet`.

Project is in a stable state.  Same "natural stopping point"
character as the v0.2.0 handoff at end of session 007 — center of
gravity moved one notch (bundling-respin, audit cleared), but no
new pressure to ship anything specific next.

## Suggested next moves

Carry-forward from session 007 HANDOFF, plus three new threads
from this session:

**A. Upstream PR for the posix_spawn patches.**  (Carry-forward.)
Out-of-band, doesn't gate anything else.  Patches 0002 + 0003 +
0004 are upstreamable in shape.  Probably an hour of prose
polishing + a `git format-patch --base` rebase against current
upstream master.  Similar in shape to PR #432 (O_CLOEXEC) and PR
#436 (arc4random_buf) — both merged.

**B. M2 — G4 + AltiVec exploration.**  (Carry-forward.)  Roadmap
items 11-13.  Non-invasive parts (`-mcpu=7450`, then `-maltivec
-mabi=altivec`) are `scripts/build-tiger.sh` variants; one
session lands both as additional tarballs.  Benchmark vs G3 is
the interesting part.

**C. M3 — G5 / 64-bit.**  (Carry-forward.)  Roadmap items 14-15.
Bootstrap-on-G3 workaround is the recommended starting point;
root-causing the `tools/patch-header.janet` Bus error is more
work.

**D. Tiger-specific test failures in deferred.md.**  (Carry-
forward.)  Two parked items:

- `os/realpath errors when path does not exist` —
  macports-legacy-support's `realpath` shim returns success on
  nonexistent paths.  Either fix in mlsupport or guard on Tiger.
- `suite-filewatch.janet` reports 17/23 on Tiger — `EVFILT_VNODE`
  flag mapping looks wrong.  Real bug, plausibly in
  `src/core/filewatch.c`.

**E. Upstream patch 0006 (`:cd` tests).**  (New.)  Small, generic
test improvement that exercises chdir success + chdir-failure
paths across all three `JANET_SPAWN_CHDIR` backends (glibc Linux,
FreeBSD, macOS 10.15+, our fork+execve fallback).  Runtime probe
gracefully skips on platforms without `:cd` support.  Probably
30 min including PR description.  Easier than the spawn-stack
PR (single file, single concept).

**F. macports-legacy-support: add CLOCK_PROCESS_CPUTIME_ID.**
(New.)  Empirical finding from this session: mlsupport's
`clock_gettime` shim only covers `REALTIME` and `MONOTONIC`.
Tiger's libc `clock()` could back a `CLOCK_PROCESS_CPUTIME_ID`
shim (same approach Janet's Mach branch uses).  Out-of-scope for
this project — it's an mlsupport conversation — but if it lands,
the "Simplify PR #937" follow-up that was reverted this session
becomes viable.  File issue or draft a patch at
[macports/macports-legacy-support](https://github.com/macports/macports-legacy-support).

**G. `-static-libgcc` for sister Tiger projects.**  (New.)  User
flagged they'd think about it separately for leopard.sh.  The
gain is the same — tarballs become truly standalone with no
`/opt/gcc-X.Y.Z` dep.  Trade-off is binary size (~12 KB for
janet, may be more for bigger projects like LLVM).

## Gotchas not to re-step on

**All session 003-007 gotchas still apply.**

New from this session:

- **macports-legacy-support's `clock_gettime` shim is
  incomplete.**  Defines `CLOCK_REALTIME` and `CLOCK_MONOTONIC`
  only.  `CLOCK_PROCESS_CPUTIME_ID` is NOT provided.  Code that
  uses all three POSIX clock IDs needs to keep a libc-`clock()`
  fallback for CPUTIME — which is exactly what Janet's Mach
  branch does and why PR #937 isn't actually redundant on Tiger.
  Don't be fooled by "mlsupport provides clock_gettime, so X is
  dead code" — check what symbol each path actually references.

- **`regen-patches.sh` produces fresh `From <SHA>` lines every
  run.**  `git format-patch` regenerates patches deterministically
  in content but the From-SHA is the underlying commit hash —
  rewriting the branch (`fetch-janet.sh`) gives those commits new
  SHAs.  Expect SHA churn on `patches/0001-0005` any time a new
  commit lands or the branch is rebuilt.  Bodies stay stable;
  the churn is purely metadata.

- **For "is bundled tarball standalone?" verification, `otool -L`
  is necessary but not sufficient.**  Test by moving the dep
  aside on the test host (ibookg37) and re-running.  Did this for
  the `-static-libgcc` claim — `mv /opt/gcc-4.9.4
  /opt/gcc-4.9.4-test-aside`, run janet, confirm "still works",
  restore.

- **Always cross-check test coverage before claiming a patch is
  "exercised."**  Patch 0003 (fork+execve fallback) was assumed
  thoroughly tested via session 006's full-suite run on Tiger,
  but `:cd` was a completely untested code path.  When asked
  "what tests exercise this?", grep the test suite for the
  relevant flag/option — don't trust narrative summaries.

- **Failed simplification attempts should be reverted, not
  retained as "documented prototypes."**  Patch 0006 v1
  (`JANET_NO_MACH_CLOCK_SHIM`) was committed, then empirically
  refuted, then reverted.  The audit proposal doc has an
  "Empirical correction" section showing the compile error and
  the mlsupport header.  This is more honest than leaving the
  patch in tree as "the opt-out exists but doesn't fully work on
  current mlsupport."

- **README's "Try it out" block needs a fresh eye every release.**
  Listed mlsupport as a prereq for the bundled tarball through
  v0.2.0 — wasn't true (bundled means bundled), just inherited
  from an earlier prereq line.  Re-derive from `otool -L` of the
  actual tarball binary each release.

## Where canonical artifacts live after this session

- `patches/0006-test-suite-os-add-tests-for-os-execute-cd-argument.patch` —
  new, test-only addition to upstream `test/suite-os.janet`.
- `docs/proposals/merged-prs-vs-mlsupport.md` — audit + empirical
  correction.  First occupant of `docs/proposals/`.
- `docs/deferred.md` — "Simplify PR #937" entry struck through
  with link to the audit doc.
- `releases/janet-1.41.3-dev-r3-tiger-g3.tar.gz` — v0.2.1 bundled.
- `releases/janet-1.41.3-dev-r3-tiger-g3-byo.tar.gz` — v0.2.1 BYO.
- GitHub release [v0.2.1](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.1).
- leopard.sh mirror — both r3 tarballs live at
  http://leopard.sh/misc/beta/.
- `scripts/build-tiger-remote.sh` — adds `-static-libgcc` to
  LDFLAGS in bundled mode only (line ~50).

## Starting prompt for session 009

```
Starting session 009.  Read docs/sessions/008-upstream-audit-and-v0.2.1/
HANDOFF.md and README.md.

v0.2.1 shipped end of session 008 — bundled tarball now has no
/opt prereqs thanks to -static-libgcc, verified standalone on
ibookg37.  Patch stack grew to 6 (0006 adds :cd tests for upstream).
Project at a stable state.

Pick one (carry-forward from 007 + new from 008):
  A. Upstream PR for posix_spawn patches (0002-0004)
  B. M2 — G4 + AltiVec
  C. M3 — G5 / ppc64
  D. Tiger test failures parked in docs/deferred.md
  E. Upstream patch 0006 (:cd tests) as a small PR
  F. macports-legacy-support: add CLOCK_PROCESS_CPUTIME_ID
  G. Apply -static-libgcc to sister Tiger projects

Each has its own writeup in HANDOFF.md "Suggested next moves".
```
