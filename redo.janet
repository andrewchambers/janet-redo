
(var build-db nil)
(var build-stack @[])
(var builder nil)

(defn exists?
  [f]
  (not (nil? (os/stat f))))

(defn rename
  [src dest]
  (when (not= (os/shell (string "mv " src " " dest)) 0)
    (error "rename failed.")))

(defn rm-if-exists
  [path]
  (when (exists? path)
    (os/rm path)))

(defn new-db-ent
  [target]
  @{:path target :if-change-deps []})

(defn update-db-ent
  [target]
  (var db-ent (build-db target))
  (when (not db-ent)
    (error (string "internal error: no db-ent, target=" target)))
  (def stat (os/stat target))
  (when (not stat)
    (error (string "unable to stat file: " target)))
  (put db-ent :modified (stat :modified))
  (put db-ent :size (stat :size))
  (put db-ent :path target))

(defn tmp-name
  [f]
  (string f ".redo.tmp"))

(defn redo
  [target]
  (for i 0 (length build-stack) (file/write stdout "  "))
  (print target)
  (def curbuild @{:target target :if-change-deps @[]})
  (array/push build-stack curbuild)
  (var db-ent (or (build-db target) (new-db-ent target)))
  (put build-db target db-ent)
  (def tmp-file (tmp-name target))
  (rm-if-exists tmp-file)
  (builder target tmp-file)
  (rename tmp-file target)
  (update-db-ent target)
  (put db-ent :if-change-deps (curbuild :if-change-deps))
  (array/pop build-stack))

(defn changed?
  [dep]
  (def db-ent (build-db dep))
  (def stat (os/stat dep))
  (or
    (not db-ent)
    (not stat)
    (not= (stat :modified) (db-ent :modified))
    (not= (stat :size) (db-ent :size))))

(defn redo-if-change 
  [& targets]
  (var parent (array/peek build-stack))
  (each target targets
    (array/push (parent :if-change-deps) target)
    (def db-ent (build-db target))
    (if (and (os/stat target) (not db-ent))
      (do
        (put build-db target (new-db-ent target))
        (update-db-ent target))
      (do 
        (var if-change-deps (when db-ent (db-ent :if-change-deps)))
        (when (or (not if-change-deps)
                  (find changed? if-change-deps)
                  (exists? (tmp-name target)))
          (redo target))))))

(defn build
  [bldr target]
  (set builder bldr)
  (when (nil? build-db)
    (set build-db @{}))
  (redo target))
