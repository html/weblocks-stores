
(defpackage #:weblocks-custom
  (:use :cl :weblocks-stores)
  (:export #:data-element #:object->data-element #:objects->data-elements)
  (:documentation
   "A driver for weblocks backend store API that works with any data but with sub-api provided by callbacks"))

(in-package :weblocks-custom)

