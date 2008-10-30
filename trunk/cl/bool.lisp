#| Copyright 2008 Google Inc. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License")
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an AS IS BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Author: madscience@google.com (Moshe Looks) |#
(in-package :plop)

(defun truth-table (expr &optional (vs (free-variables expr))
		    &aux (context (make-context)))
  (collecting
    (labels ((enum-bindings (vs)
	       (if vs
		   (dbind (v &rest vs) vs
		     (setf (getvalue v context) 'true)
		     (enum-bindings vs)
		     (setf (getvalue v context) 'false)
		     (enum-bindings vs))
		   (collect (peval-cl expr context)))))
      (mapc (bind #'bind-type /1 context 'bool) vs)
      (enum-bindings vs))))
(defun truth-table-hamming-distance (tt1 tt2)
  (let ((i 0))
    (map nil (lambda (x y) (unless (eq x y) (incf i)))
	 tt1 tt2)
    i))
(define-test truth-table-hamming-distance
  (mapc (lambda (tt1 tt2 d)
	  (assert-equal d (truth-table-hamming-distance tt1 tt2)))
	'((true true false) (true true) (false true))
	'((false true true) (true true) (true false))
	'(2 0 2)))

(defmacro test-by-truth-tables (rewrite)
  `(let ((vars (collecting (dolist (x *enum-exprs-test-symbols*)
			     (if (and (eql 0 (cdr x)) (not (const-atom-p x)))
				 (collect (car x)))))))
     (dolist (expr (enum-exprs *enum-exprs-test-symbols* 2) t)
       (unless (assert-equal (truth-table expr vars)
			     (truth-table (funcall ,rewrite expr) vars)
			     expr
			     (funcall ,rewrite expr))
	 (return nil)))))

(defun bool-dual (f) (ecase f (and 'or) (or 'and) (true false) (false true)))

;;; boolean reductions

(define-reduction push-nots (expr)
    :type bool
    :condition (and (eq (fn expr) 'not)
		    (matches (afn (arg0 expr)) (and or not)))
    :action 
    (if (eq (fn (arg0 expr)) 'not)
	(arg0 (arg0 expr))
	(pcons (bool-dual (fn (arg0 expr)))
	       (mapcar (lambda (subexpr)
			 (pcons 'not (list subexpr)))
		       (args (arg0 expr)))
	       (markup expr)))
    :order downwards
    :preserves (remove-bool-duplicates eval-const))
(define-test push-nots
  (assert-equal  '(and (not x) (not y)) (p2sexpr (push-nots %(not (or x y)))))
  (test-by-truth-tables #'push-nots))

(defmacro define-bool-dual-reductions (and-name or-name
				       (operator identity complement expr)
				       &body body)
  (flet ((dosub (x y z)
	   (subst x operator (subst y identity (subst z complement body)))))
    `(progn (define-reduction ,and-name (,expr)
	      :type bool
	      ,@(dosub ''and ''true ''false))
	    (define-reduction ,or-name (,expr)
	      :type bool
	      ,@(dosub ''or ''false ''true)))))

;; ;; (and true x y)  -> (and x y)  (or true x y)  -> true
;; ;; (and false x y) -> false      (or false x y) -> x
;; ;; (and x)         -> x          (or x)         -> x 
(define-bool-dual-reductions bool-and-identities bool-or-identities 
  (operator identity complement expr)
  :condition (and (eq operator (fn expr))
		  (or (singlep (args expr))
		      (member-if #'const-atom-p (args expr))))
  :action (cond ((eq it t) (arg0 expr))
		((find complement it) complement)
		(t (aif (remove identity (args expr))
			(if (singlep it) 
			    (car it)
			    (pcons (fn expr) it (markup expr)))
			identity)))
  :order upwards)
(define-test bool-and-identities
  (assert-equal '(and x y) (p2sexpr (bool-and-identities %(and x true y))))
   (assert-for-all (compose (bind #'eq 'false /1) #'bool-and-identities)
		   (mapcar #'sexpr2p 
			   '((and false x y) (and x false y) (and x y false))))
   (assert-equal 'x  (eval-const (bool-and-identities %(and x))))
   (test-by-truth-tables #'bool-and-identities))
(define-test bool-or-identities
  (assert-equal true (bool-or-identities %(or x true y)))
  (mapc (lambda (expr) 
	  (assert-equal '(or x y) 
			(p2sexpr (bool-or-identities (sexpr2p expr)))))
	'((or false x y) (or x false y) (or x y false)))
  (assert-equal 'x  (eval-const (bool-or-identities %(or x))))
  (test-by-truth-tables #'bool-or-identities))

(defun negate (expr)
  (if (eq (afn expr) 'not) (arg0 expr) (pcons 'not (list expr))))
(defun litvariable (x) (if (consp x) (arg0 x) x))
(defun negatesp (x y &key (pred #'eq))
  (flet ((check (neg other) 
	   (and (eq (fn neg) 'not) (funcall pred (arg0 neg) other))))
  (if (consp x) (check x y) (if (consp y) (check y x)))))
(define-test negatesp
  (assert-true (negatesp %(not x) 'x))
  (assert-true (negatesp 'x %(not x)))
  (assert-false (negatesp 'x 'x))
  (assert-false (negatesp %(not x) %(not x))))

; returns literals or literals only-children of junctors
(defun extract-literal (expr)
  (cond ((literalp expr) expr)
	((and (consp expr) (singlep (args expr)) (literalp (arg0 expr))) 
	 (arg0 expr))))

(defun var-and-negation-p (clause) ; clauses must be sorted
  (mapc (lambda (x y) 
	  (if (negatesp x y) (return-from var-and-negation-p t)))
	clause (cdr clause))
  nil)
(defun bool-identities (op)
  (ecase op
    (and 'bool-and-identities)
    (or 'bool-or-identities)))

(define-bool-dual-reductions identify-contradictions identify-tautologies 
  (operator identity complement expr)
  :assumes (sort-commutative)
  :condition (eq operator (fn expr))
  :action (if (var-and-negation-p (args expr)) complement expr)
  :order upwards)
(define-test identify-contradictions
  (flet ((mung (expr) (p2sexpr (identify-contradictions expr))))
    (assert-equal 'false (mung %(and x (not x))))
    (assert-equal '(and x (not y)) (mung %(and x (not y))))
    (assert-equal '(or z false) (mung %(or (and x (not x)) z)))
    (test-by-truth-tables #'identify-contradictions)))
(define-test identify-tautologies
  (flet ((mung (expr) (p2sexpr (identify-tautologies expr))))
    (assert-equal 'true (mung %(or x (not x))))
    (assert-equal '(or x (not y)) (mung %(or x (not y))))
    (assert-equal 'z (p2sexpr (bool-and-identities (identify-tautologies
						    %(and z (or x (not x)))))))
    (test-by-truth-tables #'identify-tautologies)))

(define-reduction remove-bool-duplicates (expr)
  :type bool
  :assumes (sort-commutative)
  :condition (and (junctorp expr) (some #'equal (args expr) (cdr (args expr))))
  :action (pcons (fn expr)
		 (remove-adjacent-duplicates (args expr) :test #'equal)
		 (markup expr))
  :order upwards)
(define-test remove-bool-duplicates
  (assert-equal '(and x z) (p2sexpr (remove-bool-duplicates %(and z x x z z))))
  (let ((expr %(and x y z)))
    (assert-eq expr (remove-bool-duplicates expr))))

(defun mkclause (expr)
  (if (junctorp expr) 
      (cons (car (args expr)) (cdr (args expr)))
      (list expr)))
(defun invert (expr) ; note - doesn't touch markup
  (case (afn expr)
    (and (pcons 'or (mapcar #'invert (args expr)) (markup expr)))
    (or  (pcons 'and (mapcar #'invert (args expr)) (markup expr)))
    (not (arg0 expr))
    (t (pcons 'not (list expr)))))
(define-test invert
  (assert-equal %(and x (not y)) (invert %(or (not x) y)))
  (test-by-truth-tables (lambda (expr) (invert (invert expr)))))
(defun shrink-by-negation (expr) 
  (case (afn expr)
    (not (arg0 expr))
    (or (invert expr))))
(defun shrinkable-by-negation-p (expr) (matches (afn expr) (not or)))
(defun make-impls (cl subcl cl2 neg)
  (delete-adjacent-duplicates (merge 'list (delete subcl (copy-list cl))
				     (delete neg (copy-list cl2) :test #'equal)
				     #'total-order)
			      :test #'equal))
(defun clause-size (x) (if (junctorp x) (length (args x)) 1))

(define-reduction reduce-bool-by-clauses (expr)
  :type bool
  :assumes (sort-commutative flatten-associative remove-bool-duplicates
	    identify-contradictions identify-tautologies
	    bool-and-identities bool-or-identities eval-const)
  :order upwards
  :condition (junctorp expr)
  :action 
  (let* ((clause-max-length 0)
	 (clause-length-pairs
	  (mapcar (lambda (x &aux (c (mkclause x)) (l (1- (length c))))
		   (setf clause-max-length (max clause-max-length l))
		   (cons c l))
		  (args expr)))
	 (clause-map (make-array (1+ clause-max-length)))
	 (subs-to-clauses (make-hash-table :test 'equal)) ;watch out
	 (initial-size (reduce #'+ (args expr) :key #'clause-size))
	 core-clauses implications)
    (print* 'gott expr)
    ;; populate the clause-map array (clauses indexed by length
    (mapc (lambda (pair) (push (car pair) (elt clause-map (cdr pair))))
	  clause-length-pairs)
    ;; populate core-clauses with the clauses which are not supersets of others
    (mapc (lambda (pair)
	    (when (dotimes (i (cdr pair) t)
		    (mapc (lambda (smaller) 
			    (when (includesp (car pair) smaller #'total-order)
			      (return)))
			  (elt clause-map i)))
	      (push (car pair) core-clauses)))
	  clause-length-pairs)
    ;; index non-negated subclauses to map to their parent clauses, and
    ;; simultaneously identify tautology/contradictions and get rid of them    
    (setf core-clauses
	  (delete-if (lambda (cl &aux negations)
		       (mapc (lambda (subcl)
			       (aif (shrink-by-negation subcl)
				    (push it negations)
				    (push cl (gethash subcl subs-to-clauses))))
			     cl)
		       (when (some (lambda (subcl)
				     (eq cl (car (gethash subcl 
							  subs-to-clauses))))
				   negations)
			 (push nil cl)))
		     core-clauses))
    
    ;; find clauses containing negated subclauses and see if they match 
    ;; any non-negated subclauses of other clauses - when a match is found,
    ;; use it to generating implications
    (mapc (lambda (cl)
	    (mapc (lambda (subcl &aux (neg (shrink-by-negation subcl)))
		    (awhen (and neg (gethash neg subs-to-clauses))
		      (mapc (lambda (cl2)
			      (when (car cl2) ; to avoid using a tautology
				(push 
				 (list (make-impls cl subcl cl2 neg) cl cl2)
				 implications)))
			    it)))
		  cl))
	  core-clauses)

    ;; when possible, shinking matching clauses for any implications found
    (mapc (lambda (i)
	    (dbind (impls cl cl2) i
	      (let ((i1 (includesp cl impls #'total-order))
		    (i2 (includesp cl2 impls #'total-order)))
		(when i1 (rplac cl (if i2 (copy-tree impls) impls)))
		(when i2 (rplac cl2 impls)))))
	  implications)

    ;; use implications to delete redundant third clauses
    (mapc (lambda (impl &aux (length (length (car impl))))
	    (dotimes (i length)
	      (mapc (lambda (smaller) 
		      (when (and (not (eq smaller (cadr impl)))
				 (not (eq smaller (caddr impl)))
				 (includesp (car impl) smaller #'total-order))
			(rplaca smaller nil)
			(return)))
		    (elt clause-map i))))
	  implications)
    (setf core-clauses (delete-if-not #'car core-clauses))

    (print* 'cc core-clauses (pcons (fn expr)
	       (let ((dual (bool-dual (fn expr))))
		 (mapcar (lambda (x) (if (singlep x) (car x) (pcons dual x)))
			 core-clauses))
	       (markup expr)))

    ;; reassemble the expr if core-clauses have shrunk
    (if (eql initial-size (reduce #'+ core-clauses :key #'length))
	expr
	(pcons (fn expr)
	       (let ((dual (bool-dual (fn expr))))
		 (mapcar (lambda (x) (if (singlep x) (car x) (pcons dual x)))
			 core-clauses))
	       (markup expr)))))

(define-test reduce-bool-by-clauses
  (flet ((assert-reduces-to (target exprs)
	   (dolist (expr exprs)
	     (let* ((pexpr (sexpr2p expr)))
	       (assert-equal target (p2sexpr 
				     (sort-commutative
				      (reduce-bool-by-clauses pexpr))))
	       (assert-equal expr (p2sexpr pexpr))))))
    (assert-reduces-to '(and x z) 
		       '((and (or x y) x z)
			 (and (or x y) x z (or x y) (or x y z))))
    (assert-reduces-to '(or x z) '((or (and x y) x z)
				   (or (and x y z) x z (and x y) (and x y z))))
    (assert-reduces-to '(and (or x y) (or (not x) z))
		       '((and (or x y) (or (not x) z) (or y z))))
    (assert-reduces-to '(or (and x y) (and (not x) z))
		       '((or (and x y) (and (not x) z) (and y z))))
    (assert-reduces-to '(or y (and (not x) z))
		       '((or (and x y) (and (not x) z) y)))
    (assert-reduces-to '(or x y) '((or x (and (not x) y))))
    (assert-reduces-to '(and x y) '((and x (or (not x) y))))
    (assert-reduces-to '(or (not x) (not y))
		       '((or (not x) 
			  (and (or (and (not y) (not x)) (and (not y) x)) 
			   (not y) x))
			 (or (not x) 
			  (and x (not y) (or (and x (not y)) 
					     (and (not x) (not y)))))))
    (assert-reduces-to '(or (not x) (and (not y) z))
		       '((or (not x) (and x (not y) z))))
    (assert-reduces-to '(or (not x) (and (not y) (f p q)))
		       '((or (not x) (and x (not y) (f p q)))))
    (assert-reduces-to '(or (not x) y (not y)) ;reduct gives true
		       '((or (not x) (not y) (and x y))))

    (test-by-truth-tables #'reduce-bool-by-clauses)))

;; ;;; if the handle set centered at expr is inconsistent, remove the subtree
;; ;;; rooted at expr
;; (define-reduction remove-inconsistent-handles (expr :parents parents)
;;   :type bool
;;   :order downwards
;; )

;; ;;; holman calls this promote-common-constraints
;; (define-reduction inverse-distribution (expr :parent parent)
;;   :condition (distributive-over expr parent)

;; ;;; holman's cut-unnecessary-or and cut-unnecessary-and
;; (define-reduction eliminate-identities (expr)
;;   :condition (and (identityp (car expr)) (not (cddr expr)))
;; )

;; ;;; constraints in expr's handle are subtracted from expr
;; (define-reduction subtract-redundant-constraints (expr :parents parents)
;;   :type bool
;; )

;; ;;; and clauses containing unit-command literals have their subtrees removed
;; (define-reduction constraint-subsumption (expr :parents parents)
;;   :type bool
;;   :condition (eq 'and (car expr))
;; )

;; ;;; the negations of unit-command literals are subtracted from and clauses
;; (define-reduction contraint-complement-subtraction (expr :parents parents)
;;   :type bool
;;   :condition (eq 'and (car expr))
;; )

;;; need to handle dangling ors and ands from holman's transformations
;;; these can be propagated upwards ... this should be a cleanup function
;;; - make cleanup any function, btw, not a reduction

;; idea - what about considering for insertion minimal trees that only use n
;; arguments? e.g. all boolean exprs with the vars, etc. these could be cached
;; in minimal form...