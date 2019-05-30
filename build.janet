#! /usr/bin/env janetsh

(import sh)
(import redo)

(defn parse-c-deps
  [path]
  (def deps
    (peg/match
      (quote {
        :ws   (some (choice (set " \n\t") "\\\n"))
        :name (capture (some (sequence (not :ws) 1)))
        :main (sequence :name :ws (any (sequence :name :ws)))
      })
      (slurp path)))
  (unless deps
    (error "bad dep file."))
  (or (tuple/slice deps 1) []))

(var JANET_CORE_OBJS
  (map string '[
     src/core/abstract.o 
     src/core/array.o 
     src/core/asm.o 
     src/core/buffer.o 
     src/core/bytecode.o 
     src/core/capi.o 
     src/core/cfuns.o 
     src/core/compile.o 
     src/core/corelib.o 
     src/core/debug.o 
     src/core/emit.o 
     src/core/fiber.o 
     src/core/gc.o 
     src/core/inttypes.o 
     src/core/io.o 
     src/core/marsh.o 
     src/core/math.o 
     src/core/os.o 
     src/core/parse.o 
     src/core/peg.o 
     src/core/pp.o 
     src/core/regalloc.o 
     src/core/run.o 
     src/core/specials.o 
     src/core/string.o 
     src/core/strtod.o 
     src/core/struct.o 
     src/core/symcache.o 
     src/core/table.o 
     src/core/tuple.o 
     src/core/typedarray.o 
     src/core/util.o 
     src/core/value.o 
     src/core/vector.o 
     src/core/vm.o 
     src/core/wrap.o
    ]))

(var JANET_BOOT_OBJS
  (map string '[
    src/boot/array_test.o 
    src/boot/boot.o 
    src/boot/buffer_test.o 
    src/boot/number_test.o 
    src/boot/system_test.o 
    src/boot/table_test.o
  ]))


(var CC "clang")
(var CFLAGS ["-O2" "-DJANET_BOOTSTRAP"])
(var LDFLAGS ["-ldl" "-lm"])

(defn builder
  [target out-path]

  (redo/redo-if-change "build.janet")

  (cond

    (string/has-suffix? ".o" target)
      (do
        (def cfile (string/replace ".o" ".c" target))
        (redo/redo-if-change cfile)
        (def depfile (string target ".d"))
        (sh/$ [CC] [CFLAGS] -MMD -MF [depfile] -I src/include -I src/core/ -c -o [out-path] [cfile])
        (redo/redo-if-change ;(parse-c-deps depfile))
        (os/rm depfile))
    
    (= target "janet_boot")
      (do
        (def all-obj (flatten ["boot.gen.o" JANET_CORE_OBJS JANET_BOOT_OBJS]))
        (redo/redo-if-change ;all-obj)
        (sh/$ [CC] [LDFLAGS] -o [out-path] [all-obj]))

    (= target "boot.gen.c")
      (do
        (redo/redo-if-change "xxd" "src/boot/boot.janet") 
        (sh/$ ./xxd "src/boot/boot.janet" [out-path] janet_gen_boot))

    (= target "xxd")
      (do
        (redo/redo-if-change "tools/xxd.c")
        (sh/$ [CC] [CFLAGS] -o [out-path] "tools/xxd.c"))

    (error (string "unknown build target: " target))))


(trace redo/redo)
(trace redo/redo-if-change)

(redo/build builder (or (process/args 1) "janet_boot"))
(setdyn :pretty-format "%.80p")
(print "build-db:")
(pp redo/build-db)
