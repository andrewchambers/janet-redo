(import redo)

(defn change-ext
  [e f]
  (string (string/slice f 0 -2) e))

(def csrc ["a.c" "b.c" "c.c"])
(def objs (map (partial change-ext "o") csrc))
(def hdrs ["all.h"])

(defn shell
  [cmd]
  (when (not= (os/shell cmd) 0)
    (error (string "'" cmd "' was not successful!"))))

(defn cc
  [cfile obj]
  (shell (string "cc -c -o " obj " " cfile)))

(defn link
  [objs bin]
  (shell (string "cc -o " bin " " (string/join objs " "))))

(defn builder
  [target out-path]
  (redo/redo-if-change "build.janet")
  (cond
    (string/has-suffix? ".o" target)
      (do
        (def cfile (change-ext "c" target))
        (redo/redo-if-change cfile ;hdrs)
        (cc cfile out-path))
    (= target "prog")
      (do
        (redo/redo-if-change ;objs)
        (link objs out-path))
    (error "unknown build target")))

(trace redo/redo)
(trace redo/redo-if-change)
(trace shell)

(redo/build builder "prog")
(print "build-db:")
(pp redo/build-db)
