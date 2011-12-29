;;;; chap2.lisp

(in-package #:hello-gl-chap3)

(defparameter +vertex-buffer-data+
  (coerce #(-1.0 -1.0 0.0 1.0
            1.0 -1.0 0.0 1.0
            -1.0 1.0 0.0 1.0
            1.0 1.0 0.0 1.0)
          '(simple-array single-float (*)))
  "Data describing the two-triangle plane of our window in 2d points.")
(defparameter +element-buffer-data+
  (coerce #(0 1 2 3) '(simple-array (unsigned-byte 16) (*)))
  "Indexes into the vertex buffer for use as a triangle list")

(defparameter +fragment-shader-source+
  "#version 110

uniform sampler2D textures[2];

varying float fade_factor;
varying vec2 texcoord;

void main()
{
    gl_FragColor = mix(
        texture2D(textures[0], texcoord),
        texture2D(textures[1], texcoord),
        fade_factor
    );
}
"
  "Source for the fragment shader")

;;; OpenGL resources
(defvar *vertex-buffer* nil
  "GL name of the vertex buffer")
(defvar *element-buffer* nil
  "GL name of the element buffer")
(defvar *texture-0* nil
  "GL name of the texture loaded from hello1.png")
(defvar *texture-1* nil
  "GL name of the texture loaded from hello2.png")

;;; GLSL uniform and attribute names
(defvar *timer-uniform* nil
  "GLSL name of the timer uniform value")
(defvar *texture-0-uniform* nil
  "GLSL name of the texture 0 uniform value")
(defvar *texture-1-uniform* nil
  "GLSL name of the texture 1 uniform value")
(defvar *position-attribute* nil
  "GLSL name of the position attribute")

;;; Shader and program names
(defvar *vertex-shader* nil
  "GL name for the vertex shader loaded from hello-gl.v.glsl")
(defvar *fragment-shader* nil
  "GL name for the fragment shader loaded from hello-gl.f.glsl")
(defvar *program* nil
  "GL name for the program composed of our vertex and fragment shader")

(defvar *timer* 0
  "Number of milliseconds since the program was started.")

(defun hello-gl-path (path)
  "Given a relative PATH, constructs a path relative to the hello-gl
system directory"
  (asdf:system-relative-pathname "hello-gl" path))

(defun make-buffer (target type data)
  "Given a GL TARGET and a TYPE from the GL types, binds the contents
of DATA to a GL buffer.  Returns the name of the GL buffer."
  (let ((buffer (first (gl:gen-buffers 1))))
    (gl:with-gl-array (arr type :count (length data))
      (dotimes (idx (length data))
        (setf (gl:glaref arr idx) (aref data idx)))
      (gl:bind-buffer target buffer)
      (gl:buffer-data target :static-draw arr))
    buffer))

(defun make-shader (type source)
  "Given a shader TYPE and SOURCE code, create a new GL shader.  An
error condition is signaled if compilation fails.  On success, returns
the GL shader name"
  (let ((shader (gl:create-shader type)))
    (gl:shader-source shader (list source))
    (gl:compile-shader shader)
    (let ((ok (gl:get-shader shader :compile-status )))
      (unless ok
        (let ((log (gl:get-shader-info-log shader)))
          (gl:delete-shader shader)
          (error "~(~a~) shader didn't compile: ~a" (symbol-name type) log))))
    shader))

(defun make-program (vertex-shader fragment-shader)
  "Given the GL names of a vertex shader and a fragment shader,
creates a GL program and links them.  An error condition is signaled
if linking fails.  On success, returns a GL program name."
  (let ((program (gl:create-program)))
    (gl:attach-shader program vertex-shader)
    (gl:attach-shader program fragment-shader)
    (gl:link-program program)
    (let ((ok (gl:get-program program :link-status)))
      (unless ok
        (let ((log (gl:get-program-info-log program)))
          (gl:delete-program program)
          (error "Program didn't link: ~a" log))))
    program))

(defun make-texture (path)
  "Given an image file at PATH, loads the image, flips it to match GL
coordinates, and binds it to a new texture.  Returns the GL name of
the new texture on success."
  (let* ((unflipped-image (sdl-image:load-image path))
         (image (sdl-gfx:rotate-surface-xy 0 :surface unflipped-image :zoomy -1)))

    (sdl-base::with-pixel (pix (sdl:fp image))
      (assert (and (= (sdl-base::pixel-pitch pix)
                      (* (sdl:width image) (sdl-base::pixel-bpp pix)))
                   (zerop (rem (sdl-base::pixel-pitch pix) 4))))
      (let ((texture-format (ecase (sdl-base::pixel-bpp pix)
                              (1 :luminance)
                              (2 :luminance-alpha)
                              (3 :rgb)
                              (4 :rgba)))
            (tex-id (first (gl:gen-textures 1))))
        (gl:bind-texture :texture-2d tex-id)
        (gl:tex-parameter :texture-2d :generate-mipmap t)
        (gl:tex-parameter :texture-2d :texture-min-filter :linear-mipmap-linear)
        (gl:tex-parameter :texture-2d :texture-mag-filter :linear)
        (gl:tex-parameter :texture-2d :texture-wrap-s :clamp-to-edge)
        (gl:tex-parameter :texture-2d :texture-wrap-t :clamp-to-edge)

        (gl:tex-image-2d :texture-2d 0 :rgba
                         (sdl:width image) (sdl:height image)
                         0
                         texture-format
                         :unsigned-byte
                         (sdl-base::pixel-data pix))
        tex-id))))

(defun make-resources (vertex-shader-path)
  "Creates the GL resources necessary to display the output of the
hello-gl program."
  (setf *vertex-buffer* (make-buffer :array-buffer :float +vertex-buffer-data+))
  (setf *element-buffer* (make-buffer :element-array-buffer
                                      :unsigned-short
                                      +element-buffer-data+))
  (setf *texture-0* (make-texture (hello-gl-path "hello1.png")))
  (setf *texture-1* (make-texture (hello-gl-path "hello2.png")))
  (assert (not (or (zerop *texture-0*)
                   (zerop *texture-1*))))
  (setf *vertex-shader*
        (make-shader :vertex-shader
                     (alexandria:read-file-into-string
                      (or vertex-shader-path
                          (hello-gl-path "hello-gl.v.glsl")))))
  (setf *fragment-shader*
        (make-shader :fragment-shader +fragment-shader-source+))
  (setf *program* (make-program *vertex-shader* *fragment-shader*))
  (setf *timer-uniform* (gl:get-uniform-location *program* "timer"))
  (setf *texture-0-uniform* (gl:get-uniform-location *program* "textures[0]"))
  (setf *texture-1-uniform* (gl:get-uniform-location *program* "textures[1]"))
  (setf *position-attribute* (gl:get-attrib-location *program* "position")))

(defun render ()
  "Renders a single frame of our scene"
  (gl:clear-color 0.1 0.1 0.1 1.0)
  (gl:clear :color-buffer-bit)

  (gl:use-program *program*)

  (gl:uniformf *timer-uniform* *timer*)
  (gl:active-texture :texture0)
  (gl:bind-texture :texture-2d *texture-0*)
  (gl:uniformi *texture-0-uniform* 0)

  (gl:active-texture :texture1)
  (gl:bind-texture :texture-2d *texture-1*)
  (gl:uniformi *texture-1-uniform* 1)

  (gl:bind-buffer :array-buffer *vertex-buffer*)
  (gl:vertex-attrib-pointer *position-attribute* 4 :float nil
                            0
                            (cffi:null-pointer))
  (gl:enable-vertex-attrib-array *position-attribute*)

  (gl:bind-buffer :element-array-buffer *element-buffer*)
  (gl:draw-elements :triangle-strip (gl:make-null-gl-array :unsigned-short)
                    :count (length +element-buffer-data+))
  (gl:disable-vertex-attrib-array *position-attribute*)

  (sdl:update-display))

(defun update-timer (dt)
  "Updates *TIMER*, given the time delta DT in milliseconds"
  (incf *timer* dt))

(defun setup-display (width height)
  "Creates a new SDL window and sets up the GL viewport"
  (sdl:window width height
              :title-caption "Hello World"
              :opengl t
              :opengl-attributes '((:sdl-gl-doublebuffer 1))))

(defun chap3 (&optional path)
  "Starts the hello-gl chapter 3 shader demonstration"
  (sdl:with-init (sdl:sdl-init-video)
    (setup-display 640 480)
    (setf *timer* 0)
    (setf cl-opengl-bindings:*gl-get-proc-address* #'sdl:sdl-gl-get-proc-address)
    (make-resources path)
    (sdl:update-display)
    (setf (sdl:frame-rate) 60)
    (sdl:with-events ()
      (:quit-event () t)
      (:key-down-event
       (:key key)
       (cond
         ((or (sdl:key= key :sdl-key-q)
              (sdl:key= key :sdl-key-escape))
          (sdl:push-quit-event))))
      (:video-expose-event ()
       (render))
      (:idle
       (update-timer (sdl:dt))
       (render)))))