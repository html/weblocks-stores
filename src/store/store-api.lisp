
(in-package :weblocks-stores)

(export '(open-store close-store clean-store *default-store*
          begin-transaction commit-transaction rollback-transaction
          dynamic-transaction use-dynamic-transaction-p
          persist-object delete-persistent-object
          delete-persistent-object-by-id find-persistent-objects
          find-persistent-object-by-id count-persistent-objects replace-on-redefine-p *debug-stores* list-model-classes
          class-visible-slots class-visible-slots-impl delete-model-class serialize unserialize *default-serialization-format* 
          store-type))

(defvar *debug-stores* t)
(setf (documentation '*debug-stores* 'variable)
      "Debugging flag, set 'T' to see record ids in repl, set 'NIL' to have usual objects behavior.")

;;; Store initialization and finalization
(defgeneric open-store (store-type &rest args)
  (:documentation "Opens a connection to a store specified by
  'store-type'. This function must return the instance of the
  connection to the store. Methods can accept any number of custom
  keyword parameters. Additionally, the function must set
  *default-store* to the value of newly created store."))

(defgeneric close-store (store)
  (:documentation "Closes a connection to the store. If the value of
  *default-store* is equal to 'store', *default-store* must be set to
  NIL."))

(defgeneric clean-store (store)
  (:documentation "Cleans all the data in the store. This function
  should erase data, but not necessarily any schema information (like
  tables, etc.)"))

(defvar *default-store* nil
  "The default store to which objects are persisted.  Bound while a
  webapp is handling a request to the value of its
  `webapp-default-store-name'.  By using `defstore' after the relevant
  `defwebapp' in the same package, barring an explicit setting, the
  webapp will be set to use the defined store automatically.")

;;; Transactions
(defgeneric begin-transaction (store)
  (:documentation "Begins a transaction on 'store'. Note, if the given
  store does not have transaction support, this function should return
  NIL without signalling errors."))

(defgeneric commit-transaction (store)
  (:documentation "Commits a transaction started on 'store'. Note, if
  the given store does not have transaction support, or the store
  isn't in a transaction, this function should return NIL without
  signalling errors."))

(defgeneric rollback-transaction (store)
  (:documentation "Rolls back a transaction started on 'store'. Note,
  if the given store does not have transaction support, or the store
  isn't in a transaction, this function should return NIL without
  signalling errors."))

(defgeneric dynamic-transaction (store proc)
  (:documentation "Call PROC, a thunk, while in a transaction of
  STORE.  See `use-dynamic-transaction-p' for details.")
  (:method (store proc)
    (warn "~S should not be called when the other transaction ~
           interface is available" 'dynamic-transaction)
    (let (tx-error-occurred-p)
      (unwind-protect
           (handler-bind ((error #'(lambda (error)
                                     (declare (ignore error))
                                     (rollback-transaction store)
                                     (setf tx-error-occurred-p t))))
             (begin-transaction store)
             (funcall proc))
        (unless tx-error-occurred-p
          (commit-transaction store))))))

(defgeneric use-dynamic-transaction-p (store)
  (:documentation "Answer whether `action-txn-hook' and equivalents
  should use GF `dynamic-transaction' for transaction control rather
  than the `begin-transaction', `commit-transaction', and
  `rollback-transaction' GFs.  Be warned that non-local exit behavior
  for stores that answer true for this may have unique non-local exit
  unwind behavior.")
  (:method (store)
    (declare (ignore store))
    nil))

;;; Creating and deleting persistent objects
(defgeneric persist-object (store object &key)
  (:documentation "Persists 'object' into 'store', answering
  'object'. If the object does not have a unique ID (see 'object-id'),
  persist 'object' into store and set its unique ID via (see '(setf
  object-id)'). If the object has a unique ID, find relevant entry in
  the store and update it with 'object'."))

(defgeneric delete-persistent-object (store object)
  (:documentation "Deletes the persistent object from 'store'. After
  deleting the persistent object, set unique ID of 'object' to
  NIL (see '(setf object-id)')."))

(defgeneric delete-persistent-object-by-id (store class-name object-id)
  (:documentation "Similar to 'delete-persistent-object', but instead
  deletes object with the specified 'object-id'."))

;;; Querying persistent objects
(defgeneric find-persistent-object-by-id (store class-name object-id)
  (:documentation "Finds and returns a persistent object of a given
  class name in a given store by its unique id. If the object isn't
  found, returns NIL."))

(defgeneric find-persistent-objects (store class-name
                                           &key order-by range
                                           &allow-other-keys)
  (:documentation "Looks up and returns objects of appropriate
  'class-name' in the 'store' bound by the given keyword
  parameters.

  If 'order-by' is specified, orders the returned objects by the given
  slot in the given order. If 'order-by' is not NIL, it is expected to
  be a cons cell with slot name as 'car' and :asc or :desc as
  'cdr'.

  If 'range' is specified, returns only the specified range of
  objects. The CAR of 'range' is the index of the initial
  object (inclusive) and CDR is the index past the last object. Note,
  the range should be applied after the objects have been filtered and
  ordered if necessary.

  Other implementation dependent keys may be defined by a given
  store."))

(defgeneric count-persistent-objects (store class-name &key &allow-other-keys)
  (:documentation "Returns the number of persistent objects stored in
  'store' of 'class-name', bound by the given keyword parameters. For
  documentation of keyword parameters, see
  'find-persistent-objects'.

  Other implementation dependent keys may be defined by a given
  store."))

(defgeneric replace-on-redefine-p (store-type)
  (:documentation "When true replaces existing store on reexecuting (defstore ...) block.")
  (:method (store-type)
   nil))

(defgeneric list-model-classes (store)
  (:documentation "Returns list with symbols - models class names"))

;;; Scaffold utilities
(defun class-visible-slots (cls &key readablep writablep)
  "Converts 'cls' to class object if it is a name, and calls
'class-visible-slots-impl'."
  (class-visible-slots-impl (if (and (symbolp cls)
                                     (not (null cls)))
                                (find-class cls)
                                cls)
                            :readablep readablep
                            :writablep writablep))

(defgeneric class-visible-slots-impl (cls &key readablep writablep)
  (:documentation "Returns a list of 'standard-direct-slot-definition'
objects for a class and its subclasses. Slots objects for slots that
do not have reader accessors are filtered out and not returned.

If 'readablep' is true, filters out the slots that don't have a
reader (or accessor) defined.
If 'writablep' is true, filters out the slots that don't have a
writer (or accessor) defined.")
  (:method (cls &key readablep writablep)
    (unless (or (null cls)
                (eql (class-name cls) 'standard-object))
      (remove-if (lambda (item)
                   (or (null item)
                       (and readablep
                            (null (c2mop:slot-definition-readers item)))
                       (and writablep
                            (null (c2mop:slot-definition-writers item)))))
                 (flatten
                  (append (mapcar #'class-visible-slots
                                  (c2mop:class-direct-superclasses cls))
                          (c2mop:class-direct-slots cls)))))))

(defgeneric delete-model-class (store  cls)
            (:documentation "Completely removes model class. `list-model-classes` should not contain class after calling this method.")
            (:method (store cls)
                     (setf (find-class cls) nil)))

(defvar *default-serialization-format* nil)
(setf (documentation '*default-serialization-format* 'variable)
      "Debugging flag, set 'T' to see record ids in repl, set 'NIL' to have usual objects behavior.")

(defgeneric serialize (obj &key format)
  (:documentation "Method for serialization of objects, objects sets for specific model and stores."))

(defgeneric unserialize (obj &key format)
  (:documentation "Method for deserialization of objects, objects sets for specific model and stores."))

(defgeneric store-type (store)
  (:documentation "Should return keyword type of store")
  (:method ((store null))
   nil)
  (:method (store)
   (error "Unimplemented store-type for class of store ~A" store)))
