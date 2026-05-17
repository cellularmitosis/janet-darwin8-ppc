# What does native ppc64 buy Janet?

Pre-work for M3 (G5 / 64-bit).  Triggered by a session-010 question:
*"Does native 64-bit support buy us anything useful in Janet?  I
seem to remember all values are actually nan-boxed.  Is 32-bit Janet
actually using 32-bit floats for values, or is it actually using
software 64-bit floats?  (Or does G3 actually support 64-bit
floats?)"*

Worth answering carefully before committing engineering time to a
separate ppc64 tarball variant (roadmap item 12), as the answer
shapes whether item 12 is a clear win or a marginal one.

## TL;DR

- **G3 has hardware 64-bit doubles.**  Every PowerPC chip since the
  601 (1993) has a full 64-bit double-precision FPU.  FPRs are 64
  bits wide on G3/G4/G5; `fadd`/`fmul`/`fdiv` operate on doubles in
  a single instruction.  Zero software floats anywhere in our
  stack.
- **32-bit Janet uses hardware 64-bit doubles for `number`.**  The
  "32" in `JANET_NANBOX_32` refers to the *payload width* (the
  pointer/int32 slot), not the float precision or even the slot
  size.  Every Janet value is 8 bytes regardless of bitness.
- **ppc64 buys Janet a real but modest win**, almost entirely on
  the *integer* side — not floating-point.

## What Janet's source actually says

[`external/janet/src/include/janet.h:533`](../../../external/janet/src/include/janet.h):

```c
#ifdef JANET_NANBOX_64
union Janet {
    uint64_t u64;
    int64_t  i64;
    double   number;
    void    *pointer;
};
#elif defined(JANET_NANBOX_32)
union Janet {
    struct {
        // BE: type first, then payload
        uint32_t type;
        union { int32_t integer; void *pointer; } payload;
    } tagged;
    double   number;   // ← still a hardware double
    uint64_t u64;
};
#else
/* Non-nanbox fallback: 16-byte struct of {payload, type} */
struct Janet { union { uint64_t u64; double number; ... } as; JanetType type; };
#endif
```

Both nanbox layouts are **8 bytes**.  Both store `number` as a
hardware double.  The 64-bit version encodes the type in the high
bits of a NaN pattern so the whole value lives in one 64-bit
register; the 32-bit version has type and payload as adjacent
32-bit fields, addressed by split 32-bit loads on access.

Auto-selection — [`janet.h:115`](../../../external/janet/src/include/janet.h):

```c
#if /* a bunch of 64-bit arch checks, including: */ \
    || (defined(__ppc64__) || defined(__PPC64__)) ...
#define JANET_64 1
#else
#define JANET_32 1
#endif
```

`JANET_NANBOX_32` is selected when `JANET_32` is defined.
`JANET_NANBOX_64` is gated tighter:

```c
#elif defined(__x86_64__) || defined(_WIN64) || defined(__riscv) || \
      defined(__aarch64__) || defined(_M_ARM64)
#define JANET_NANBOX_64
```

— so **even when we build for ppc64, Janet won't auto-enable 64-bit
nanboxing.**  We'd need to either pass `-DJANET_NANBOX_64` and
verify the 47-bit-address-space assumption holds on Tiger ppc64 (it
does for kernel-managed userland), or extend that `#elif` to include
`__PPC64__` in our patch stack.  Worth thinking about in advance —
it's the difference between "ppc64 build with the 32-bit value
layout" (no value-layout speedup) and "ppc64 build with the actual
64-bit nanbox" (where the wins below live).

## What ppc64 actually buys, ranked

1. **Native `int/s64` / `int/u64` arithmetic.**  Janet exposes
   typed 64-bit integers via the `int/s64` and `int/u64` abstract
   types.  On ppc32 these compile to multi-instruction sequences
   with carry chains (the gcc 64-bit-on-32-bit-arch ABI: `adde`,
   `addze`, etc.).  On ppc64 each becomes a single instruction
   (`add`, `sub`, `mulld`, `cmpd`).  Big constant-factor win for
   `int/s64`-heavy code; zero effect on code that sticks to
   `number` (the float64 default).

2. **64-bit nanbox layout** *(only if we enable it for ppc64).*
   Single 64-bit register holds the entire value.  Removes the
   load-pair/store-pair the 32-bit nanbox needs to copy/compare a
   slot.  Saves on value moves, hashing, marshalling, type
   dispatch in the interpreter inner loop.  Modest constant-factor
   win throughout the interpreter — probably single-digit %.

3. **>4 GB address space.**  Real only if a G5 has >4 GB RAM and
   the workload wants it.  Not realistic on this fleet (pmacg5
   likely has 1–2 GB).

4. **Wider GPRs for native-module C code.**  Niche; only matters
   if a future native module hand-tunes 64-bit integer paths.

## What ppc64 does *not* buy

- **Floating-point performance.**  G3/G4/G5 share the same 64-bit
  FPU semantics.  `-mcpu=970` on ppc64 won't make `fmul` faster
  than on ppc32.  Janet's `number` math is unchanged.
- **Precision.**  Doubles are doubles.  No effect.
- **AltiVec.**  G5 has it, but Janet's bytecode interpreter has no
  auto-vectorizable hot loops (settled in [session
  009](../009-m2-g4-altivec/)).  Same conclusion as the G4 case.

## So what shape should M3 take?

The roadmap already splits M3 into two items:

- **Item 11 — G5 bootstrap workaround.**  Get a *ppc32* binary
  that runs on G5.  The G3 tarball already runs on G5 by
  PPC forward-compat (verified by session 009's matrix logic).
  Question is whether *building on G5* hits the
  `tools/patch-header.janet` Bus error the leopard.sh 1.27.0
  recipe ran into.  Strategy: bootstrap on G3, scp host-janet to
  G5, use it during the G5 build.

- **Item 12 — true ppc64 build.**  Separately produce
  `janet-X.Y.Z-tiger-g5-ppc64.tar.gz`.  This is where the wins
  above kick in.  Requires `-arch ppc64` propagated through the
  build, a ppc64 build of macports-legacy-support, and probably
  some Tiger-SDK linker dance (10.4u SDK does support `-arch
  ppc64`, but it's lightly trodden).

Given the writeup above, the **interesting work** in M3 lives in
item 12.  Item 11 is mostly "smoke the existing G3 tarball on
pmacg5, then maybe root-cause the Bus error if cheap" — a likely
quick win that produces a shipping story for G5 owners without
needing a new tarball variant.

Suggested order:

1. **Item 11 first**, as a small win.  Verify the G3 tarball runs
   on pmacg5.  If it does, that *is* a complete G5 story for
   userland (G5 owners can `curl | tar x` the existing v0.2.1
   tarball today).  Document the verification.  If building on G5
   matters to anyone, try the bootstrap-on-G3 workaround and
   report whether it sidesteps the Bus error.
2. **Item 12 as the substantive M3 piece.**  ppc64 toolchain
   plumbing → ppc64 mlsupport → ppc64 Janet build →
   `-DJANET_NANBOX_64` patch (or extending the upstream `#elif`)
   → benchmark vs the ppc32 tarball running on the same G5
   hardware → decision on whether to ship the variant.  This
   mirrors the M2 / session 009 methodology: build the capability,
   benchmark honestly, ship only if there's a measurable win.

The benchmark step is non-negotiable: just like AltiVec, "the
architecture supports it" doesn't equal "Janet's interpreter sees
a win from it."  We have to measure on real workload to know.

## Open questions to verify before/during M3

- **Does the 47-bit-address-space assumption underlying
  `JANET_NANBOX_64` hold on Tiger ppc64 userland?**  Mac OS X
  10.4 ppc64 supports 64-bit userland but the actual address-space
  layout under the kernel is something we should confirm before
  enabling the wider nanbox.  If userland addresses can have bits
  set above 47, we'd silently miscompile.  Reading the Tiger
  ppc64 kernel docs or running a small probe (allocate a series of
  large mappings, observe the address bits) is the right check.

- **Does macports-legacy-support build clean for ppc64?**  We've
  only ever built it for ppc.  The codebase is mostly portable C,
  but linker invocations and `lipo`-related Makefile bits may
  assume single-arch ppc.  Worth a smoke before committing to the
  variant.

- **What's the `BOOT_CFLAGS` story for ppc64?**  Janet's bootstrap
  binary (`janet_boot`) uses `BOOT_CFLAGS` not `CFLAGS`, so a
  blanket `-arch ppc64` in `CFLAGS` doesn't propagate.  If the
  bootstrap binary builds ppc32 and the final binary builds ppc64,
  that's fine *as long as* both run on the build host.  On
  pmacg5 (a 64-bit-native machine) both should work; on a G3/G4
  build host doing cross-targeting, the ppc32 bootstrap is what
  runs natively.

## Related findings

- **AltiVec / vectorization** — [session
  009](../009-m2-g4-altivec/README.md).  Empirically settled.
- **`@loader_path`-based linking** for standalone tarballs —
  carries over unchanged to ppc64.
- **macports-legacy-support's role** — same on ppc64; we need a
  ppc64 build of its dylib bundled in the ppc64 tarball under
  `@loader_path/`.
