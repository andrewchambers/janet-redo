(import redo)

(defn change-ext
  [e f]
  (string (string/slice f 0 -2) e))

(def csrc ["a.c" "b.c" "c.c"])
(def objs (map (partial change-ext "o") csrc))
(def hdrs ["all.h"])

(defn builder
  [target out-path]
  (print "building: " target)
  (cond
    (string/has-suffix? ".o" target)
      (do
        (def cfile (change-ext "c" target))
        (os/shell (string "set -x ; cc -c -o " out-path " " cfile))
        # Deps can come after build. Great for accurate dependecy information.
        (redo/redo-if-change cfile ;hdrs))
    (= target "prog")
      (do
        (redo/redo-if-change ;objs)
        (os/shell (string "set -x ; cc -o " out-path " " (string/join objs " "))))
    (error "unknown build target")))

(trace redo/build)
(trace redo/redo)
(trace redo/redo-if-change)

(redo/build builder "prog")
(print "-------")
(os/touch "b.c")
(redo/build builder "prog")
(print "-------")
(os/touch "all.h")
(redo/build builder "prog")
(print "-------")
(redo/build builder "prog")
