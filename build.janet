(import redo)

(defn change-ext
  [e f]
  (string (string/slice f 0 -2) e))

(def csrc ["a.c" "b.c" "c.c"])
(def objs (map (partial change-ext "o") csrc))
(def hdrs ["all.h"])

(defn shell
  [& cmds]
  (def scmd (string ;cmds))
  (when (not= (os/shell scmd) 0)
    (error (string "'" scmd "' was not successful!"))))

(defn cc
  [cfile obj]
  (shell "cc -c -o " obj " " cfile))

(defn link
  [objs bin]
  (shell "cc -o " bin " " (string/join objs " ")))

(defn builder
  [target out-path]

  # everything depends on our build script.
  (redo/redo-if-change "build.janet")
  
  (cond
    (string/has-suffix? ".o" target)
      (do
        (def cfile (change-ext "c" target))
        (when (= "c.c" cfile)
          (redo/redo-if-change "foo.dat"))
        (redo/redo-if-change cfile ;hdrs)
        (cc cfile out-path))
    (= target "foo.dat")
      (do
        (redo/redo-if-change "foo.in")
        (shell "cp foo.in " out-path))
    (= target "prog")
      (do
        (redo/redo-if-change ;objs)
        (link objs out-path))
    (error (string "unknown build target: " target))))


(trace redo/redo)
(trace redo/redo-if-change)
(trace redo/changed?)
(trace shell)

(redo/build builder (or (process/args 2) "prog"))
(print "build-db:")

(setdyn :pretty-format "%.80p")
(pp redo/build-db)
