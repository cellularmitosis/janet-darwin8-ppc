# Commits — session 008

Outer repo (this project), in chronological order.

- `fff3b4f` — **patches: add 0006 - JANET_NO_MACH_CLOCK_SHIM
  opt-out for Mach clock fallback**.  First attempt at simplifying
  PR #937's gate.  Adds `JANET_NO_MACH_CLOCK_SHIM` opt-out so the
  `#elif` falls through to the POSIX `clock_gettime()` branch.
  Also refreshes patches/0001-0005 metadata (SHA churn from
  `external/janet/` having been rewritten since the last regen).
  Later reverted — see `53361ba`.

- `f3dfb10` — **docs: capture mlsupport-vs-merged-PRs audit as a
  standalone proposal**.  New
  [`docs/proposals/merged-prs-vs-mlsupport.md`](../../proposals/merged-prs-vs-mlsupport.md)
  with per-PR mapping vs mlsupport coverage.  Initial verdict:
  PR #937 worth a follow-up simplification; other three earn
  their keep.  Creates `docs/proposals/` (first occupant) per the
  `deferred.md` convention.  Updated `deferred.md` to expand the
  existing #937 entry + add a pointer to the new proposal doc.

- `53361ba` — **patches: drop 0006 - mlsupport's clock_gettime
  shim is incomplete**.  Empirical refutation of `fff3b4f`.
  Building on ibookg38 with `-DJANET_NO_MACH_CLOCK_SHIM` failed:
  `error: 'CLOCK_PROCESS_CPUTIME_ID' undeclared`.  Reading
  mlsupport's `time.h` confirmed it only defines `CLOCK_REALTIME`
  and `CLOCK_MONOTONIC`.  Removed `patches/0006`, refreshed
  0001-0005 metadata, updated the audit doc with an "Empirical
  correction" section, struck the deferred.md entry.

- `49cc3ae` — **sessions/README: HANDOFF.md mandatory, project-
  README update unconditional**.  Minor docs polish in the
  sessions workflow.  Made by the user mid-session; not a
  substantive session-008 artifact but listed for completeness.

- `7dd3ec9` — **patches: add 0006 - test/suite-os: :cd success +
  failure tests**.  The *real* patch 0006.  Adds two assertions
  to upstream's `test/suite-os.janet` exercising the `:cd`
  argument to `os/execute`, which previously had no coverage in
  the test suite.  Closes the largest untested code path in our
  fork+execve fallback.  uranium: 60/60, ibookg38: 59/60 (0
  skipped — runtime probe found `:cd` supported), no regression.

- `4c4f6a5`, `d25bff5` — **convos**.  User-maintained
  conversation transcripts in `docs/convos/`.  Not session-008
  engineering artifacts.

- `df4a209` — **README: correct prereqs for the bundled tarball**.
  User-spotted error: README listed mlsupport as a system prereq
  for the bundled tarball, but bundled means bundled — `otool -L`
  shows `@loader_path` reference.  Fixed to list only
  gcc-libs-4.9.4 as the system prereq.

- `490aa0c` — **scripts/build-tiger-remote: -static-libgcc in
  bundled mode**.  Adds `-static-libgcc` to LDFLAGS, conditional
  on `BYO_MACPORTS_LEGACY` being empty.  Bundled binary loses its
  runtime dep on `/opt/gcc-4.9.4/lib/libgcc_s.1.dylib` (and
  bonus: also `/usr/lib/libgcc_s.1.dylib` — Janet didn't need any
  libgcc helpers not already in libSystem).  BYO unchanged.

- `98e703b`, `f0a6327` — **README: bump recommended download to
  v0.2.1 (bundling respin)** + small follow-up tweak.  Status
  section flipped to v0.2.1 URLs, release table grew a v0.2.1
  row, "Try it out" prereq line drops gcc-libs, Linking & install
  table grows a "-static-libgcc on bundled tarball" row.

External/janet branch: two commits attempted (`a592f854` —
JANET_NO_MACH_CLOCK_SHIM opt-out, dropped during revert; and
`9e45bf97` — `:cd` test addition, which survives as `patches/0006`).
After all the rebuilds + revert work + regens, the current
darwin-ppc branch is +6 commits past the pinned SHA, with the
6th being the `:cd` test addition.

GitHub release: [v0.2.1](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.1)
with both `r3` tarballs attached.  Mirrored to mini10v + leopard.sh.
Pushed to `origin/main`.
