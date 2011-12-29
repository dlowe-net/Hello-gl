;;;; package.lisp

(defpackage #:hello-gl-chap2
  (:use #:cl)
  (:export #:chap2))

(defpackage #:hello-gl-chap3
  (:use #:cl)
  (:export #:chap3))

(defpackage #:hello-gl
  (:use #:cl #:hello-gl-chap2 #:hello-gl-chap3)
  (:export #:chap2 #:chap3))

