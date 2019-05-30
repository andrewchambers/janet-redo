
(var build-db nil)
(var build-stack @[])
(var builder nil)
(var dbfile "./jredo.db")



(defn exists?
  [f]
  (not (nil? (os/stat f))))

(defn rename
  [src dest]
  (when (not= (os/shell (string "mv " src " " dest)) 0)
    (error "rename failed.")))

(defn make-build
  [target]
  @{:path target :if-change-deps @[] :state nil})

(defn tmp-name
  [f]
  (string f ".redo.tmp"))

(defn read-file-state
  [path]
  (def stat (os/stat path))
  (if stat
    { :modified (stat :modified)
      :size     (stat :size)}
    (error (string path " missing."))))

(defn refresh-state
  [target]
  (def db-ent (build-db target))
  (put db-ent :state (read-file-state target))
  (each dep (db-ent :if-change-deps)
    (refresh-state dep)))

(defn redo
  [target]
  (def curbuild (make-build target))
  (array/push build-stack curbuild)
  (def tmp-file (tmp-name target))
  (when (exists? tmp-file)
    (os/rm tmp-file))
  (builder target tmp-file)
  (rename tmp-file target)
  (put build-db target curbuild)
  (array/pop build-stack))

(defn changed?
  [target]
  (def stat (os/stat target))
  (def db-ent (build-db target))
  (or (not stat)
      (not db-ent)
      (not= (read-file-state target) (db-ent :state))
      (find changed? (db-ent :if-change-deps))))

(defn redo-if-change 
  [& targets]
  (each target targets
    (def db-ent (build-db target))
    (if (and (os/stat target) (not db-ent))
      (do
        (def build (make-build target))
        (put build-db target build))
      (when (or (not db-ent)
                (not (exists? target))
                (exists? (tmp-name target))
                (find changed? (db-ent :if-change-deps)))
        (redo target))))
  (array/concat ((array/peek build-stack) :if-change-deps) targets))

(defn build
  [bldr target]
  (set builder bldr)
  (when (nil? build-db)
    (if (exists? dbfile)
      (set build-db (unmarshal (slurp dbfile)))
      (set build-db @{})))
  (redo target)
  (refresh-state target)
  (spit (tmp-name dbfile) (marshal build-db))
  (rename (tmp-name dbfile) dbfile)
  (os/shell "sync"))

