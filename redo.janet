
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

(defn new-db-ent
  [target]
  @{:path target :if-change-deps []})

(defn tmp-name
  [f]
  (string f ".redo.tmp"))

(defn redo
  [target]
  (def curbuild @{:target target :if-change-deps @[]})
  (array/push build-stack curbuild)
  (var db-ent (or (build-db target) (new-db-ent target)))
  (put build-db target db-ent)
  (def tmp-file (tmp-name target))
  (when (exists? tmp-file)
    (os/rm tmp-file))
  (builder target tmp-file)
  (rename tmp-file target)
  (put db-ent :if-change-deps (curbuild :if-change-deps))
  (array/pop build-stack))

(defn read-file-idents
  [path]
  (def stat (os/stat path))
  (if stat
    { :path path
      :modified (stat :modified)
      :size     (stat :size)}
    (error (string path " missing."))))

(defn changed?
  [dep]
  (def stat (os/stat (dep :path)))
  (or (not stat)
      (not= (read-file-idents (dep :path)) dep)))

(defn redo-if-change 
  [& targets]
  (each target targets
    (def db-ent (build-db target))
    (if (and (os/stat target) (not db-ent))
      (put build-db target (new-db-ent target))
      (do 
        (if (or (not db-ent)
                (find changed? (db-ent :if-change-deps))
                (exists? (tmp-name target))
                (not (exists? target)))
          (redo target))))
    (def file-idents (read-file-idents target))
    (each parent build-stack
      (when (not (find (fn [dep] (= target (dep :path))) (parent :if-change-deps)))
        (array/push (parent :if-change-deps) file-idents)))))

(var dbfile "./jredo.db")

(defn build
  [bldr target]
  (set builder bldr)
  (when (nil? build-db)
    (if (exists? dbfile)
      (set build-db (unmarshal (slurp dbfile)))
      (set build-db @{})))
  (redo target)
  (spit (tmp-name dbfile) (marshal build-db))
  (rename (tmp-name dbfile) dbfile)
  (os/shell "sync"))

