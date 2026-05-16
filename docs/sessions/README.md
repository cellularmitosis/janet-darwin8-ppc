# Sessions

One directory per work session, globally numbered.  Each session dir
contains:

- `README.md` — narrative of what happened.  First paragraph =
  status-on-arrival.  Last paragraph = status-on-exit.  Everything
  in between is what happened, in roughly chronological order, with
  enough detail that a future session can reconstruct the thinking.
- `HANDOFF.md` — primer for the next session.  **Write one every
  session.**  The only valid reason to skip is that the entire
  project has run out of roadmap and there is literally nothing
  left to do — and even then a HANDOFF.md saying so is more useful
  than silence.  A "clean stopping point" is not a reason to skip;
  a release boundary is itself worth flagging in a HANDOFF so the
  next session knows the center-of-gravity moved.  Include the
  open punch list (priority-ordered), methodology gotchas a future
  you would re-step on, where the canonical artifacts live now,
  and a literal prompt-block at the bottom for paste-into-fresh-
  session use.  Convention borrowed from sister project
  `llvm-7-darwin-ppc`; canonical example at
  [`../../../llvm-7-darwin-ppc/docs/sessions/032-llvm8-primary-and-ghc/HANDOFF.md`](../../../llvm-7-darwin-ppc/docs/sessions/032-llvm8-primary-and-ghc/HANDOFF.md).
- `findings.md` — "things we learned this session that will matter
  later." Bullets are fine. (optional — many sessions fold this
  into README.md.)
- `commits.md` — commits landed this session, one-liner each.
  (optional)
- `build-logs/` — captured build/test output worth keeping.
  (optional)

## Naming

`NNN-<short-slug>/`

`NNN` is a global, monotonically-increasing session number across
the project's whole life, starting at `001`.  The slug should hint
at substantive content (`001-bring-up-and-pin`,
`004-posix-spawn-pipes`) so sessions are skimmable from `ls`.

Borrowed from
[`llvm-7-darwin-ppc/docs/sessions/`](../../../llvm-7-darwin-ppc/docs/sessions/)
and [`lumo-darwin8-ppc/docs/sessions/`](../../../lumo-darwin8-ppc/docs/sessions/).
Earlier sibling projects (`golang-darwin8-ppc`, `ghc-darwin8-ppc`)
use a date-based scheme that drifts into hard-to-skim form once a
project runs months.  The numbered scheme stays compact.

## Start-of-session checklist

1. Skim the most recent session's `README.md` for context.
2. **If a `HANDOFF.md` exists alongside that README, read it first** —
   it's the explicit pickup doc and supersedes anything ambiguous in
   the README.  Reading order, suggested next moves, and gotchas-not-
   to-re-step-on live there.
3. Glance at [`../roadmap.md`](../roadmap.md) for priorities.
4. If `external/janet/` hasn't been set up yet (first session, fresh
   clone), run `scripts/fetch-janet.sh` (added in session 001).
5. Confirm baseline before changing anything load-bearing:
   - Patches re-apply cleanly to the pinned SHA.
   - Last release's tarball still installs on ibookg37 (sanity).

## End-of-session ritual

1. Commit the work itself.
2. **Print the next session's `HANDOFF.md` path** in your closing
   summary, as a clickable relative path, so the user can jump
   straight to it.
3. Write this session's `README.md` (and `findings.md` /
   `commits.md` if there's enough material to warrant them).
4. **Write `HANDOFF.md`.**  Every session, not just the messy
   ones.  Open questions, in-flight experiments, the "I'd start
   with #N next" recommendation, gotchas the next-you would
   re-step on, and where the canonical artifacts live after
   anything moved this session.  Include a paste-into-fresh-
   session prompt block at the bottom.  The only valid skip is
   total project roadmap exhaustion — and even then, a HANDOFF.md
   saying so is better than silence.
5. Update [`../roadmap.md`](../roadmap.md) if priorities shifted.
6. **Update the project README** to reflect anything user-visible
   that changed this session — status table flips, perf numbers,
   sister-project version bumps, deprecations.  Even sessions that
   don't ship a release usually move the status forward in some
   way.  If a release *did* ship, additionally update the Releases
   section and tag the commit.
7. Commit the session notes (and HANDOFF.md if you wrote one).
