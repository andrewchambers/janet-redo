
(var has-built-lut nil)
(var changed-cache nil)
(var build-db nil)
(var build-stack @[])
(var builder nil)
(var dbfile "./jredo.db")

(defn exists?
  [f]
  (not (nil? (os/stat f))))

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
  [target &opt refreshed-set]
  (default refreshed-set @{})
  (when (not (refreshed-set target))
    (put refreshed-set target true)
    (def db-ent (build-db target))
    (put db-ent :state (read-file-state target))
    (each dep (db-ent :if-change-deps)
      (refresh-state dep refreshed-set))))

(defn redo
  [target]
  (when (has-built-lut target)
    (break))
  (def curbuild (make-build target))
  (array/push build-stack curbuild)
  (def tmp-file (tmp-name target))
  (when (exists? tmp-file)
    (os/rm tmp-file))
  (builder target tmp-file)
  (os/rename tmp-file target)
  (put build-db target curbuild)
  (array/pop build-stack)
  (put has-built-lut target true))

(defn changed?
  [target]
  (when (not (nil? (changed-cache target)))
    (break (changed-cache target)))
  (def stat (os/stat target))
  (def db-ent (build-db target))
  (def changed 
    (or (not stat)
        (not db-ent)
        (not= (read-file-state target) (db-ent :state))
        (find changed? (db-ent :if-change-deps))))
  (put changed-cache target changed)
  changed)

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
  (set changed-cache @{})
  (set has-built-lut @{})
  (set builder bldr)
  (when (nil? build-db)
    (if (exists? dbfile)
      (set build-db (unmarshal (slurp dbfile)))
      (set build-db @{})))
  (redo target)
  (refresh-state target)
  (spit (tmp-name dbfile) (marshal build-db))
  (os/rename (tmp-name dbfile) dbfile))

