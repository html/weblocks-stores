
;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-
(defpackage #:weblocks-prevalence-asd
  (:use :cl :asdf))

(in-package :weblocks-prevalence-asd)

(defsystem weblocks-prevalence
  :name "weblocks-prevalence"
  :maintainer "Olexiy Zamkoviy, Scott L. Burson"
  :author "Slava Akhmechet"
  :version "0.2.1"
  :licence "LLGPL"
  :description "A weblocks backend for cl-prevalence."
  :depends-on (:metatilities :cl-ppcre :cl-prevalence :bordeaux-threads :weblocks-memory :weblocks-stores)
  :components ((:file "prevalence")))
