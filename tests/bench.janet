# Tiny portable Janet benchmark.  Times a handful of workloads that
# exercise different bits of the runtime — VM dispatch, FP arithmetic,
# integer/byte loops, GC pressure — and prints wall-clock seconds for
# each.  Used in session 009 (M2 G4 + AltiVec) to compare G3 vs G4 vs
# G4+AltiVec tarballs running on the same hardware.
#
# Self-tuning: we calibrate counts on first use so the whole thing
# takes a few seconds and gives sub-1% variance on a 1.4 GHz G4.
# Pass --quick to halve every count for a smoke run.

(def quick? (or (= (get (dyn :args) 1) "--quick") false))
(def scale (if quick? 0.5 1.0))

(defn bench
  "Run thunk and print elapsed wall-clock seconds to 3 decimals."
  [tag thunk]
  (def t0 (os/clock))
  (def result (thunk))
  (def t1 (os/clock))
  (printf "  %-20s %7.3f s" tag (- t1 t0))
  (when (string? result) (prinf "   (= %s)" result))
  (print)
  (- t1 t0))

# --- 1. Naive recursive fib --- VM dispatch + frame allocation.
(defn fib [n]
  (if (< n 2) n
      (+ (fib (- n 1)) (fib (- n 2)))))

# --- 2. Mandelbrot --- FP-heavy inner loop (best auto-vec candidate).
(defn mandel-count [cx cy max-iter]
  (var x 0.0) (var y 0.0) (var i 0)
  (while (and (< i max-iter)
              (< (+ (* x x) (* y y)) 4.0))
    (def nx (+ (- (* x x) (* y y)) cx))
    (def ny (+ (* 2 x y) cy))
    (set x nx) (set y ny)
    (set i (+ i 1)))
  i)

(defn mandel-grid [w h max-iter]
  (var total 0)
  (for py 0 h
    (for px 0 w
      (def cx (- (* (/ px w) 3.5) 2.5))
      (def cy (- (* (/ py h) 2.0) 1.0))
      (set total (+ total (mandel-count cx cy max-iter)))))
  total)

# --- 3. Big PEG match --- integer/byte inner loop.
(def big-peg-grammar
  ~{:main (some (+ :word :sep))
    :word (some (range "az" "AZ" "09"))
    :sep (some (set " ,.;:!?\t\n"))})

(defn run-peg [text n]
  (var total 0)
  (for _ 0 n
    (def m (peg/match big-peg-grammar text))
    (when m (set total (+ total (length m)))))
  total)

# --- 4. Marshal round-trip --- struct/table walking + byte buffer work.
(defn make-struct [depth fanout]
  (if (zero? depth)
    {:leaf "hello world, this is a leaf node with some content"
     :n 12345 :f 3.14159265 :b true}
    (let [t @{:depth depth :tag (string "node-" depth)}]
      (each i (range fanout)
        (put t (keyword (string "child-" i))
             (make-struct (dec depth) fanout)))
      (table/to-struct t))))

(defn run-marshal [s n]
  (var bytes 0)
  (for _ 0 n
    (def buf (marshal s))
    (def s2 (unmarshal buf))
    (set bytes (+ bytes (length buf))))
  bytes)

(defn human-int [n]
  (string n))

(def fib-n          (math/floor (* scale 30)))
(def mandel-w       (math/floor (* scale 200)))
(def mandel-h       (math/floor (* scale 150)))
(def mandel-iter    100)
(def peg-text       (string/repeat
                      "the quick brown fox jumps over the lazy dog 1 2 3, "
                      (math/floor (* scale 200))))
(def peg-iters      (math/floor (* scale 200)))
(def marsh-depth    (if quick? 6 7))
(def marsh-fanout   3)
(def marsh-iters    (math/floor (* scale 80)))

(printf "Janet %s %s on %s/%s%s"
        janet/version
        janet/build
        (os/which) (os/arch)
        (if quick? "  [--quick]" ""))
(printf "")
(printf "Workloads:")
(printf "  fib(%d), mandelbrot %dx%d/%d-iter, peg x%d on %d-byte text, marshal d%dxf%d x%d"
        fib-n mandel-w mandel-h mandel-iter peg-iters (length peg-text)
        marsh-depth marsh-fanout marsh-iters)
(printf "")

(def t-fib    (bench "fib"          (fn [] (human-int (fib fib-n)))))
(def t-mandel (bench "mandelbrot"   (fn [] (human-int (mandel-grid mandel-w mandel-h mandel-iter)))))
(def t-peg    (bench "peg-match"    (fn [] (human-int (run-peg peg-text peg-iters)))))
(def marsh-s  (make-struct marsh-depth marsh-fanout))
(def t-marsh  (bench "marshal"      (fn [] (human-int (run-marshal marsh-s marsh-iters)))))

(printf "")
(printf "  total:               %7.3f s" (+ t-fib t-mandel t-peg t-marsh))
