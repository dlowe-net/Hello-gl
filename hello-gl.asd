;;;; hello-gl.asd

(asdf:defsystem #:hello-gl
  :serial t
  :depends-on (lispbuilder-sdl lispbuilder-sdl-image lispbuilder-sdl-gfx cl-opengl)
  :components ((:file "package")
               (:file "chap2")
               (:file "chap3")))

