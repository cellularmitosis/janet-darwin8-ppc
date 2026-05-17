# int-s64-bench.janet — exercise the int/s64 / int/u64 arithmetic path,
# which the source dive predicted as the main ppc64 win (single-
# instruction native 64-bit ops vs ppc32 multi-instruction carry
# chains).  The default bench.janet stays in `number` (hardware
# double) territory and doesn't hit this path.
#
# Workloads:
#   1. s64 sum loop — millions of int/s64 add/sub/mul.
#   2. s64 factorial-ish — multiplies in a loop.
#   3. u64 hash mixing — a Fowler-Noll-Vo-style mix of u64 bits;
#      stresses xor + shift + mul on 64-bit operands.
#
# (os/clock) is used the same way as bench.janet; printed values are
# best-of-5 in the harness loop above.

(def quick? (or (= (get (dyn :args) 1) "--quick") false))
(def scale (if quick? 0.5 1.0))

(defn bench
  [tag thunk]
  (def t0 (os/clock))
  (def result (thunk))
  (def t1 (os/clock))
  (printf "  %-20s %7.3f s   (= %s)" tag (- t1 t0) (string result))
  (- t1 t0))

# 1. s64 sum: accumulate a + b - c repeatedly.  Tests add/sub.
(defn s64-sum [n]
  (var acc (int/s64 0))
  (def one (int/s64 1))
  (def two (int/s64 2))
  (def three (int/s64 3))
  (for i 0 n
    (set acc (+ acc one))
    (set acc (- acc two))
    (set acc (+ acc three)))
  acc)

# 2. s64 mul mix: a *= 3 ; a -= b ; a += b * 2 — tests mul.
(defn s64-mulmix [n]
  (var acc (int/s64 1))
  (def b (int/s64 7))
  (def three (int/s64 3))
  (def two (int/s64 2))
  (for i 0 n
    (set acc (+ (- (* acc three) b) (* b two)))
    # Reset every so often to avoid overflow saturation effects.
    (when (= 0 (mod i 32))
      (set acc (int/s64 1))))
  acc)

# 3. u64 hash mixing — FNV-style, but mixes shifts and xors.
# Note: u64 literals above 2^53 need string ctors (Janet number
# literals are doubles, which lose precision past 53 bits).
(defn u64-mix [n]
  (var h (int/u64 "14695981039346656037"))
  (def prime (int/u64 1099511628211))
  (def mask (int/u64 "18446744073709551615")) # 2^64 - 1
  (for i 0 n
    (set h (band (* h prime) mask))
    (set h (bxor h (int/u64 i)))
    (set h (band (blshift h 7) mask))
    (set h (bxor h (brshift h 13))))
  h)

(def n1 (math/floor (* scale 500000)))   # adds/subs
(def n2 (math/floor (* scale 200000)))   # muls
(def n3 (math/floor (* scale 200000)))   # u64 mix

(printf "Janet %s %s on %s/%s%s"
        janet/version janet/build (os/which) (os/arch)
        (if quick? "  [--quick]" ""))
(printf "Workloads:")
(printf "  s64-sum x%d   s64-mulmix x%d   u64-mix x%d" n1 n2 n3)
(printf "")

(def t1 (bench "s64-sum"    (fn [] (s64-sum n1))))
(def t2 (bench "s64-mulmix" (fn [] (s64-mulmix n2))))
(def t3 (bench "u64-mix"    (fn [] (u64-mix n3))))
(printf "")
(printf "  total:               %7.3f s" (+ t1 t2 t3))
