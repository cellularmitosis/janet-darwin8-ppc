# patches/

`git format-patch` output of our delta against upstream
`janet-lang/janet` (pinned to a specific master SHA — see
[`../docs/plan.md`](../docs/plan.md#pinned-upstream-version)).

These are the canonical record of our fork.  `external/janet/.git`
is the working copy; this directory is regenerated from it via
`scripts/regen-patches.sh` (added in session 001).

Naming: `000N-<short-kebab-slug>.patch`, monotonically numbered in
the order they should apply.

Empty for now.  The first expected patch is
`0001-posix-spawn-fallback.patch` — providing a `fork()`+`execve()`
fallback when `<spawn.h>` / `posix_spawn` is unavailable (Mac OS X
pre-10.5).  Starting point: the sketch in
[`install-janet-1.27.0.sh`](https://leopard.sh/tigersh/scripts/install-janet-1.27.0.sh)
on leopard.sh, debugged to working.

All patches in this directory should be **upstreamable in shape** —
small, well-motivated, no Tiger-specific paths.  Tiger build
orchestration lives in [`../scripts/`](../scripts/), not in patches.
