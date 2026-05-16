# v0.1.0-hello.janet — janet-darwin8-ppc v0.1.0 demo
#
# Run via the wrapper:  demos/v0.1.0-hello.sh
# Or directly:          /opt/janet-1.41.3-dev/bin/janet demos/v0.1.0-hello.janet
#
# Exercises four flavors of Janet to prove the install is healthy:
#   1. peg/match                                 — built-in PEG VM
#   2. fiber/new + yield + resume                — coroutines
#   3. string/format + os/which + os/arch        — basic runtime + libc
#   4. (require "lzo")                           — native module via dlopen
#
# The lzo block is wrapped so the demo is still runnable on installs
# that don't yet have janet-lzo's lzo.so dropped under lib/janet/.

(print)
(print (string/format "=== janet-darwin8-ppc v0.1.0 hello — Janet %s on %s/%s ==="
                      janet/version (os/which) (os/arch)))
(print)

# --- 1. PEG: split janet/version into (semver, optional tag) -------------------

(def version-grammar
  ~{:main    (* (<- :version) (? (* "-" (<- :tag))) -1)
    :version (* :digit+ "." :digit+ "." :digit+)
    :digit+  (some (range "09"))
    :tag     (some (+ (range "az" "AZ" "09") "-" "_" "."))})

(def parsed (peg/match version-grammar janet/version))
(print (string/format "[1] peg/match parsed %j -> %j" janet/version parsed))

# --- 2. Fiber: lazy fibonacci generator ----------------------------------------

(defn fib-fiber []
  (fiber/new
    (fn []
      (var a 0)
      (var b 1)
      (forever
        (yield a)
        (def next (+ a b))
        (set a b)
        (set b next)))))

(def f (fib-fiber))
(def fibs (seq [_ :range [0 12]] (resume f)))
(print (string/format "[2] fiber yielded fib(0..11) = %j" fibs))

# --- 3. string/format ----------------------------------------------------------

(def pi 3.14159265358979)
(print (string/format "[3] string/format: pi=%.5f  hex=%x  pad=%6d|" pi 255 42))

# --- 4. LZO native module ------------------------------------------------------
#
# Uses runtime `require` rather than the `import` macro so a missing
# lzo.so degrades to a polite skip instead of a compile-time error.

(def lzo-mod (try (require "lzo") ([_err] nil)))
(if lzo-mod
  (let [compress   (get-in lzo-mod [(symbol "compress")   :value])
        decompress (get-in lzo-mod [(symbol "decompress") :value])
        payload    (buffer (string/repeat "the quick brown fox jumps over the lazy dog. " 200))
        compressed (compress payload)
        decompressed (decompress compressed)
        ok         (= (string payload) (string decompressed))]
    (print (string/format "[4] lzo: %d -> %d bytes (ratio %.4f), round-trip ok=%j"
                          (length payload)
                          (length compressed)
                          (/ (length compressed) (length payload))
                          ok))
    (unless ok (error "lzo round-trip mismatch")))
  (do
    (print "[4] lzo: skipped (module not found)")
    (print "    drop lzo.so into /opt/janet-1.41.3-dev/lib/janet/ to enable")))

(print)
(print "ok.")
(print)
