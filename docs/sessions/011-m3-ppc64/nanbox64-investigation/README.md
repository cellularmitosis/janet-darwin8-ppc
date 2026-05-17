# `JANET_NANBOX_64` on big-endian ppc64 — investigation, parked

Session 011 attempted to enable Janet's `JANET_NANBOX_64` layout on
ppc64 by adding `__PPC64__` / `__ppc64__` to the auto-detect at
[`janet.h:313`](../../../external/janet/src/include/janet.h).  The
patch produced a binary that builds cleanly, runs basic eval cleanly,
and benchmarks **slightly faster** than the no-nanbox fallback
(1.634 s vs 1.656 s total best-of-5 on imacg52 — within 1.4%, mostly
noise).

But under closer inspection, the resulting binary has **real
correctness bugs in array mutation paths**.  We're parking the patch
here and shipping `v0.2.2` *without* it — the no-nanbox ppc64 build
gets the FP / VM-dispatch / `int/s64` wins (15% faster than ppc32)
and is correct.  The `JANET_NANBOX_64` opportunity remains; it's a
separately-debuggable big-endian issue in upstream Janet.

## Symptoms

On a `JANET_NANBOX_64`-enabled ppc64 build (gcc-4.9.4, Tiger 10.4.11
on G5):

```janet
(var x 42)
(print x (type x))     # → empty (nil)

(def b @[10 20 30 40])
(put b 0 100)
(pp b)                 # → @[10 20 30 40]  (no mutation)

(put @{:a 1} :b 2)     # → @{:a 1 :b 2}    (works on tables)

(array/push @[] 42)    # → @[42]           (works on arrays)
```

So:
- **Array literal construction works** (e.g. `@[10 20 30 40]`
  contains the right values).
- **Array slot read works** (`(b 0)` returns 10).
- **Array slot write via `put` silently no-ops.**
- **Array slot write via `array/push` works.**
- **Table `put` works.**
- **Top-level `var` is broken because it's implemented internally
  via a 1-element array + `put`** — the broken `put` makes every
  global `var` read back as nil.  Function-local `var` (inside a
  `do`/`fn`/`let`) works because the compiler resolves it as a
  stack slot rather than an array cell.

The same source + same patch builds cleanly on x86_64 and aarch64
upstream; the bug is specific to **big-endian ppc64** (the only
big-endian target where `JANET_NANBOX_64` has ever been enabled).

## Sanity checks that hold

- The 47-bit-address-space invariant holds for Tiger ppc64 userland.
  Probe in [`../probe-address-space-v2.c`](../probe-address-space-v2.c)
  / log in [`../build-logs/probe-address-space-v2.log`](../build-logs/probe-address-space-v2.log)
  shows every heap, code, and static-data address comfortably below
  bit 31.  Only the stack reaches bit 50, and Janet doesn't NaN-box
  stack pointers.  So the layout itself isn't the problem.
- `janet/config-bits = 1` confirms the `JANET_NANBOX_BIT` is set in
  the binary's config, and `nm` shows `_janet_nanbox_to_pointer`
  (which only exists in the NANBOX_64 path), so the build is
  genuinely using `JANET_NANBOX_64`.
- The same binary with the same gcc-4.9.4 but using the *no-nanbox*
  16-byte-struct layout (just `-m64`, no NANBOX patch) behaves
  correctly under all the same tests.  So the bug lives entirely
  in the `JANET_NANBOX_64` code path interacting with ppc64
  big-endian.

## Suspected root cause (untested)

`janet_put` reads the value out of a stack slot (`stack[C]`, a
`Janet` union by-value), then assigns `array->data[index] = value`.
`array/push` is given a `JanetArray *` and a `Janet` and does the
same final assignment but without the value-passing-through-args
step.

On Darwin ppc64 (Mach-O, SysV-ish ABI), aggregates of size ≤ 8
bytes containing both an integer member (`uint64_t`) and a
floating-point member (`double`) have ABI corner cases.  In
particular: returning a `union { uint64_t; double; void *; }` from
a function may use FP-register conventions on some toolchains and
GPR conventions on others, and passing the same union by value may
have similar split behavior.

If `janet_nanbox_to_pointer` (which takes the union by value, masks
its `u64`, and returns it as `void *`) goes through the FP register
path when the source value was stored via the integer path (or vice
versa), the read can come back as a different bit pattern — typically
zero or NaN-like, which then unwraps as a null pointer.

This would explain why `put` silently no-ops: `janet_unwrap_array`
returns 0, and `array->data[index] = value` then writes to a
nonsense location.  (Wait — that should *crash*, not no-op.)  So
that's not quite right either.

More plausible: the `value` argument to `janet_put` is what's
getting corrupted on the union-by-value path, and what's actually
written to `array->data[index]` is a Janet-nil-bit-pattern.  Then
re-reading the slot returns nil, which the print loop folds to an
empty string.  That matches the `(var x ...) ; x → nil` symptom
exactly.

Confirmed: the array's underlying `data` pointer is *correctly*
identified (no crash), but the *value* being stored is being
clobbered to nil during the by-value union pass.

## Why we're not fixing it this session

The fix probably means either:
1. Changing `janet_nanbox_to_pointer` / `janet_nanbox_from_pointer`
   etc. to pass `Janet` by const-pointer instead of by-value (avoids
   the ABI hazard, but touches the API).
2. Adding `__attribute__((aligned(...)))` or an explicit `union`
   tagged layout to force a single ABI convention.
3. Adding an explicit big-endian `JANET_NANBOX_64_BE` variant that
   uses different bit layout to sidestep the ABI issue.

All three are upstream changes, not Tiger-build changes.  The
correct path is:

- Ship `v0.2.2` with the ppc64 variant *without* NANBOX_64 — it's
  15% faster than ppc32 and correct.
- File the NANBOX_64 ppc64 issue against upstream `janet-lang/janet`
  with this reproducer.
- If upstream fixes it, our patch becomes a 2-line addition to the
  auto-detect (the same as what's parked here) and we revisit.
- If the perf delta of NANBOX_64 vs no-nanbox is small enough (we
  measured 1.4%, mostly noise), this might never be worth the
  complexity.  The 15% win is from ppc64 itself, not from NANBOX_64.

## The patch (parked)

[`0007-janet.h-enable-JANET_NANBOX_64-on-ppc64.patch`](0007-janet.h-enable-JANET_NANBOX_64-on-ppc64.patch)
— extends the upstream auto-detect at `janet.h:313` to include
`__PPC64__` / `__ppc64__`.  Re-apply on top of the 6-patch stack to
reproduce the bug.  Don't ship.

## How to reproduce the bug

On a Tiger G5 host with gcc-4.9.4 and the project's build setup:

```
# Apply the parked patch.
cp docs/sessions/011-m3-ppc64/nanbox64-investigation/0007-*.patch patches/
scripts/fetch-janet.sh

# Build ppc64.
TIGER_HOST=imacg52 TIGER_ARCH=g5-ppc64 scripts/build-tiger.sh

# On imacg52, install + smoke.
ssh imacg52 'cd /opt && sudo tar xzf ~/janet-1.41.3-dev-tiger-g5-ppc64.tar.gz'
ssh imacg52 '/opt/janet-1.41.3-dev/bin/janet -e "(def b @[10 20]) (put b 0 100) (pp b)"'
# expected (correct): @[100 20]
# observed (bug):     @[10 20]
```
