hello-gl
--------

This contains a Common Lisp implementation of the tutorial found at
[An intro to modern OpenGL][intro].


To use, asdf-install or use quicklisp to install these library
dependencies:

* lispbuilder-sdl
* lispbuilder-sdl-image
* lispbuilder-sdl-gfx
* cl-opengl

Load the hello-gl system with asdf, then execute with:

    (hello-gl:chap2)  ;; for chapter 2

You can exit by pressing the `q' or `escape' keys.

[intro]:http://duriansoftware.com/joe/An-intro-to-modern-OpenGL.-Chapter-1:-The-Graphics-Pipeline.html
