# Session 008 — upstream PR audit, test coverage, v0.2.1 bundling respin

**Status on arrival.**  v0.2.0 published end of session 007.  M1.b
done; project at a natural stopping point.  Session 007 HANDOFF
listed four candidate next moves (A. upstream PR for posix_spawn,
B. M2 G4+AltiVec, C. M3 G5/ppc64, D. Tiger test failures from
deferred.md).  The user picked a sideline instead: revisit
previously-merged upstream PRs to see which had become redundant
under macports-legacy-support.

**Status on exit.**  v0.2.1 published — a bundling-only respin of
v0.2.0 that drops the runtime dep on `gcc-libs-4.9.4` via
`-static-libgcc`.  Bundled tarball is now genuinely standalone (no
`/opt` prereqs); verified on ibookg37 by moving `/opt/gcc-4.9.4`
aside and confirming janet still runs.  Patch stack grew by one:
`patches/0006` adds `:cd` success + failure tests to upstream's
`test/suite-os.janet`, closing the largest coverage gap in our
fork+execve fallback.  A failed simplification attempt
(`JANET_NO_MACH_CLOCK_SHIM`) was reverted and documented; led to
the discovery that mlsupport's `clock_gettime` shim is incomplete
(no `CLOCK_PROCESS_CPUTIME_ID`).

## What happened

### 1. Audit of merged upstream PRs vs mlsupport coverage

User question: now that macports-legacy-support is in the picture,
which of my (the user's) previously-merged portability PRs in
upstream janet have become redundant or simplifiable?

Inventoried user-authored commits in `external/janet/` via
`git log --author='Pepas' --oneline`.  Ten merged commits, of which
four are portability workarounds in the runtime:

- PR #432 (+ `5565f02d`) — O_CLOEXEC support
- PR #436 (+ `f5d208d5`) — arc4random_buf support
- `f06e9ae3` — /dev/urandom for OS X < 10.7
- PR #937 — Mach `clock_get_time` shim

The other six (`f270739f`, `ab910d06`, `e9870b29`, `43139b43`,
`a110b103`, `51bf8a35`) are cosmetic/refactor/build/unrelated.

An Explore-agent pass over mlsupport's header layout +  Janet's
gate code produced the initial mapping (in
[`docs/proposals/merged-prs-vs-mlsupport.md`](../../proposals/merged-prs-vs-mlsupport.md)).
Initial verdict: only **PR #937** looked worth a follow-up
simplification PR — mlsupport provides `clock_gettime`, so the
Mach shim appeared to be dead code on Tiger.  Already pre-flagged
in `docs/deferred.md` under "Simplify PR #937's clock-shim gate."

### 2. Patch 0006 v1 — `JANET_NO_MACH_CLOCK_SHIM` (committed, then reverted)

Wrote `patches/0006` adding an opt-out flag to the Mach clock
shim's gate.  When `JANET_NO_MACH_CLOCK_SHIM` is defined (via
`CPPFLAGS`), the `#elif` falls through to the POSIX
`clock_gettime()` branch, which would resolve via mlsupport on
Tiger.  Default behavior unchanged for everyone not opting in.

Committed in `external/janet/` (`a592f854`), regen'd patches,
landed in outer repo as `fff3b4f`.  Wrote the audit doc + linked
from `deferred.md` as `f3dfb10`.

### 3. Empirical refutation

User asked about test coverage before pushing.  Ran scenario 1
(`make test` on uranium, no flag) — green, 0 regressions.  Then
wired `-DJANET_NO_MACH_CLOCK_SHIM` into
`scripts/build-tiger-remote.sh` and built on ibookg38:

```
src/core/util.c:1040:15: error: 'CLOCK_PROCESS_CPUTIME_ID' undeclared
make: *** [Makefile:200: build/core/util.boot.o] Error 1
```

Read mlsupport's `time.h` (at
`/opt/macports-legacy-support-20221029/include/LegacySupport/time.h`):
only `CLOCK_REALTIME` and `CLOCK_MONOTONIC` are defined.  No
`CLOCK_PROCESS_CPUTIME_ID`.  Janet's POSIX `clock_gettime` path
uses all three.

The Mach branch the gate wraps has a *separate* CPUTIME path via
libc `clock()` — precisely because mlsupport's coverage was always
partial.  PR #937 is correctly written; my "dead code" framing
was wrong.

Reverted: removed `patches/0006`, reverted the
`build-tiger-remote.sh` edit, updated the audit doc with an
**Empirical correction** section showing the compile error + the
mlsupport header + Janet's POSIX path code.  Updated `deferred.md`
to strike the "Simplify PR #937" entry.  Committed as `53361ba`.

### 4. Test coverage — patch 0006 v2 (the real one)

User asked: now that we know the fallback works on Tiger via the
session-006 baseline, is upstream's test suite *fully* exercising
all our fallback's code paths?

Mapped patch 0003's code paths to existing tests in
`suite-os.janet` + `suite-ev.janet`.  Most paths covered (pipe_in,
pipe_out, file-fd stdout/stderr, `:err :out`, custom env, execvp,
post-spawn kill/wait).  Gaps:

- **`:cd` (chdir in child)** — patch 0003 specifically adds
  `JANET_SPAWN_CHDIR` for our fallback, but no upstream test
  exercises it.  Biggest gap; meaningful for our code.
- `execv` (no-`:p`) branch — every Janet test uses `:p`.  Dead
  code in the test suite.
- `:in <file>` (stdin from non-pipe fd) — no test.
- `:err :pipe` (stderr to pipe directly) — no test.
- Exec failure (nonexistent binary) — no direct test.
- System failures (pipe/fork/fcntl) — impractical.

Added two tests for `:cd` to `test/suite-os.janet`:

- `:cd` to `(os/cwd)` — chdir success → exec success.
- `:cd` to `/nonexistent-abc123def456` — chdir failure → errpipe
  write → waitpid reap → panic.

Runtime probe gates the tests with `skip-asserts` for platforms
that lack `:cd` support (Windows, mingw, macOS pre-10.15 without
our fallback, non-glibc Linux), so it's upstreamable as-is.

Built on ibookg38, `suite-os.janet` reports **59 of 60 tests
passed (0 skipped)** — the 1 fail is the pre-existing
`os/realpath` shim issue, our two new tests pass, and "0 skipped"
confirms the runtime probe found `:cd` supported and exercised
the real path.

Committed in `external/janet/` (`9e45bf97`), regen'd, landed as
`7dd3ec9`.

### 5. README prereq correction

User spotted: README's "Try it out" block lists
`macports-legacy-support-20221029` as a prerequisite alongside
`gcc-libs-4.9.4`.  But the bundled tarball ships mlsupport
inside `lib/` via `@loader_path` — it's not a system prereq.

`otool -L` confirmed on a fresh build on ibookg38: only
`@loader_path/../lib/libMacportsLegacySupport.dylib` +
`/usr/lib/libgcc_s.1.dylib` + `/opt/gcc-4.9.4/lib/libgcc_s.1.dylib`
+ `/usr/lib/libSystem.B.dylib`.  Fixed README to list only
gcc-libs-4.9.4 as the system prereq, with a parenthetical that
the `-byo.tar.gz` variant is the one needing mlsupport at `/opt`.
Committed as `df4a209`.

### 6. `-static-libgcc` — the gcc-libs dep goes too

User asked: can we drop the `/opt/gcc-4.9.4` dep entirely?  Or
bundle libgcc_s via `@loader_path` like we do mlsupport?

Surveyed four options: (1) `-static-libgcc`, (2) bundle
libgcc_s.dylib, (3) both, (4) keep status quo.  Recommended (1) —
industry-norm for shipping binaries built with non-system
compilers.  User agreed, scoped to bundled mode only (BYO unchanged).

Added `-static-libgcc` to `LDFLAGS` in
`scripts/build-tiger-remote.sh`, gated on `BYO_MACPORTS_LEGACY`
being empty.  Built on ibookg38:

```
bin/janet:
    @loader_path/../lib/libMacportsLegacySupport.dylib   (bundled)
    /usr/lib/libSystem.B.dylib                            (Tiger stock)
```

Both `libgcc_s` references dropped — the `/opt/gcc-4.9.4` one
(expected) AND Tiger's own `/usr/lib/libgcc_s.1.dylib` (bonus —
Janet's code didn't need any libgcc helpers not in libSystem).
Binary grew 12 KB (1.735 → 1.747 MB).  `suite-os.janet`
59/60, no regression.  Committed as `490aa0c`.

### 7. v0.2.1 release

Built `janet-1.41.3-dev-r3-tiger-g3.tar.gz` (bundled) and
`janet-1.41.3-dev-r3-tiger-g3-byo.tar.gz` (BYO, byte-equivalent
to v0.2.0 BYO modulo timestamps).

**Gold-standard standalone verification** on ibookg37 (test host,
separate from build host per CLAUDE.md): installed the bundled
tarball, `otool -L` matched expectations, then `mv /opt/gcc-4.9.4
/opt/gcc-4.9.4-test-aside`, ran janet, confirmed it still works
(`"still works without /opt/gcc-4.9.4 1.41.3-dev"`), restored.

README updated to bump recommended download to v0.2.1, add v0.2.1
row to Releases table (and retroactive note on v0.2.0's
gcc-libs dep), add a `-static-libgcc` row to the Linking & install
table.  Committed as `f0a6327`.

GitHub release [v0.2.1](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.1)
created with both tarballs.  Mirrored to both `mini10v` (source
of truth, rsyncs to leopard.sh) and `leopard.sh` directly
(immediate live).  Verified
http://leopard.sh/misc/beta/janet-1.41.3-dev-r3-tiger-g3.tar.gz
returns HTTP 200.

## What this didn't do

- Did not actually file any upstream PR — the audit's conclusion
  (none of the merged PRs warrant simplification) made the
  upstream-PR question moot for the four runtime-shim PRs.  The
  spawn-stack PR (patches 0002-0004) and the new `:cd` test
  contribution (patch 0006) remain unfiled.
- Did not propagate `-static-libgcc` to sister Tiger projects.
  User noted they'd think about it separately for leopard.sh.
- Did not start M2 (G4+AltiVec) or M3 (G5/ppc64) work.
