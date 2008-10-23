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

Author: madscience@google.com (Moshe Looks) 

This defines various basic semantic operations for the language used to
represent evolved programs. |#
(in-package :plop)

;;; for convenice - the language uses these instead of t and nil
(defvar true 'true)
(defvar false 'false)

;; a total ordering on all plop expressions
;; returns less, nil, or greater, with the important property that (not symbol)
;; is always ordered immediately after symbol
;; markup is ignored
(defun total-cmp (l r)
  (flet ((elem-cmp (l r)
	   (if (numberp l)
	       (if (numberp r)
		   (if (= l r) nil (if (< l r) 'less 'greater))
		   'less)
	       (if (numberp r)
		   'greater
		   (if (eql l r) nil (if (string< l r) 'less 'greater))))))
    (if (consp l)
	(if (eq (fn l) 'not)
	    (if (eqfn r 'not)
		(total-cmp (arg0 l) (arg0 r))
		(or (total-cmp (arg0 l) r) 'greater))
	    (if (consp r)
		(if (eq (fn r) 'not)
		    (or (total-cmp l (arg0 r)) 'less)
		    (or (elem-cmp (fn l) (fn r))
			(prog () (mapl 
				  (lambda (l r)
				    (aif (total-cmp (car l) (car r))
					 (return it)
					 (let ((x (consp (cdr l))) 
					       (y (consp (cdr r))))
					   (unless (eq x y)
					     (return (if x 'greater 'less))))))
				  (args l) (args r)))))
		'greater))
	(if (consp r)
	    (if (eq (fn r) 'not) 
		(or (total-cmp l (arg0 r)) 'less)
		'less)
	    (elem-cmp l r)))))
(defun total-order (l r)
  (print* 'to l r)
  (eq (total-cmp l r) 'less))
(define-test total-order
   (assert-equal '(1 2 3) (sort-copy '(3 1 2) #'total-order))

   (assert-equal `(,%(a 1) ,%(a 1 1) ,%(a 2))
		 (sort-copy `(,%(a 2) ,%(a 1) ,%(a 1 1)) #'total-order))
   (assert-equal 
    `(1 2 a b c nil ,%(a 1) ,%(a 2) ,%(b b) ,%(b b b))
    (sort-copy `(2 b 1 a c ,%(a 2) ,%(a 1) ,%(b b) ,%(b b b) nil)
	       #'total-order))
   (assert-equal
    `(,%(a (a (b c))) ,%(a (a (b c)) b) ,%(a (a (b c d))))
    (sort-copy `(,%(a (a (b c))) ,%(a (a (b c)) b) ,%(a (a (b c d))))
	       #'total-order))
   (assert-equal `(a ,%(not a) b ,%(not b) c)
		 (sort-copy `(,%(not a) ,%(not b) c b a) #'total-order)))

;;; properties of functions
(defun commutativep (x)
  (matches x (and or * +)))
(defun associativep (x)
  (matches x (and or * +)))
(macrolet ((build-identity-functions (items)
	     `(progn
		(defun identityp (x)
		  (matches x ,(mapcar #'car items)))
		(defun identity-elem (x)
		  (ecase x ,@items)))))
  (build-identity-functions
   ((and 'true) (or 'false) (* 1) (+ 0) (append nil))))
(defun purep (x) ; for now no side-effects - these will be introduced soon
  (declare (ignore x))
  t)
(defun closurep (x) ; gp closure - all args are of same type as the output
  (matches x (and or not + * - / exp log sin append)))

;;; properties of expressions
(defun junctorp (expr) (matches (afn expr) (and or)))
(defun literalp (expr)
  (if (consp expr)
      (and (eq (fn expr) 'not) (not (consp (arg0 expr))))
      (not (matches expr (true false)))))
(defun pequal (expr1 expr2) ;;; tests equality sans markup
  (if (atom expr1) 
      (and (atom expr2) (eql expr1 expr2))
      (and (consp expr2)
	   (eq (fn expr1) (fn expr2))
	   (let ((a1 (args expr1)) (a2 (args expr2)))
	     (when (eql (length a1) (length a2))
	       (mapc (lambda (sub1 sub2) (unless (pequal sub1 sub2)
					   (return-from pequal)))
		     a1 a2)
	       t)))))
(defun expr-size (expr)
  (if (atom expr) 1 
      (reduce #'+ (args expr) :key #'expr-size :initial-value 1)))
(defun arity (expr) (length (args expr)))
(defun free-variables (expr) ;;fixme extend to non-boolean, lambda-awareness...
  (if (consp expr)
      (case (fn expr)
	((and or not) (reduce (bind #'delete-adjacent-duplicates 
				    (merge 'list /1 /2 #'string<))
			      (args expr)
			      :key #'free-variables)))
      (unless (const-atom-p expr) (list expr))))
(define-test free-variables
  (assert-equal '(x y z)
		(sort (free-variables %(and (or x y) (or (not x) z) y)) 
		      #'string<)))
(defun lambdap (value) 
  (and (consp value) (consp (car value)) (eq (caar value) 'lambda)))
(defun tuple-value-p (expr) (arrayp expr))

;;; constness
(defun const-atom-p (x &optional (context *empty-context*))
  (and (atom x) (or (not (symbolp x)) 
		    (matches x (true false nan nil)) 
		    (valuedp x context))))

(defun const-expr-p (expr &optional (context *empty-context*))
  (cond ((atom expr) (const-atom-p expr context))
	((eq (fn expr) 'lambda)
	 (with-nil-bound-values context (fn-args expr)
	   (const-expr-p (fn-body expr) context)))
	(t (every (bind #'const-expr-p /1 context) (args expr)))))
(defun const-value-p (expr &optional (context *empty-context*))
  (cond
    ((atom expr) (const-atom-p expr context))
    ((eq (fn expr) 'lambda) (with-nil-bound-values context (fn-args expr)
			      (const-expr-p (fn-body expr) context)))
    ((purep (fn expr)) (every (bind #'const-value-p /1 context) (args expr)))))
(define-test const-value-p
  (assert-false (const-value-p 'x))
  (assert-true (const-value-p 42))
  (assert-true (const-value-p %(lambda (x) (+ x 1))))
  (assert-false (const-value-p %(lambda (x) (+ x y))))
  (assert-true (const-value-p %(list 1 2 3)))
  (assert-false (const-value-p %(list 1 2 x 3))))

;;; converting values to expressions (like quote)
(defun value-to-expr (value)
  (cond ((and (consp value) (not (lambdap value))) (pcons 'list value))
	((tuple-value-p value) (pcons 'tuple (coerce value 'list)))
	(t value)))

;;; breaking apart expressions
(defmacro dexpr (expr-name (fn args markup) &body body) ;;; destructure expr
  `(let ((,fn (fn ,expr-name))
	 (,args (args ,expr-name))
	 (,markup (markup ,expr-name)))
     ,@body))
(macrolet ;;; decompositions of expressions by contents
    ((mkdecomposer (name &body conditions)
       `(defmacro ,name (expr &body clauses)
	  `(cond ,@(mapcar (lambda (clause)
			     (dbind (pred &body body) clause
			       (let ((condition 
				      (case pred
					((t) 't)
					,@conditions
					(t (if (consp pred)
					       `(matches (ifn ,expr) ,pred)
					       `(eq (ifn ,expr) ',pred))))))
				 `(,condition ,@body))))
			   clauses)))))
  (mkdecomposer decompose-num
		(const `(numberp ,expr)))
  (mkdecomposer decompose-bool
		(literal `(literalp ,expr))
		(const `(matches ,expr (true false)))
		(junctor `(junctorp ,expr)))
  (mkdecomposer decompose-tuple)
  (mkdecomposer decompose-function)
  (mkdecomposer decompose-list))
(define-test decompose-num
  (assert-equal 
   '(cond ((numberp expr) foo) 
     ((eq (ifn expr) '/) goo)
     ((matches (ifn expr) (* +)) loo)
     (t moo))
   (macroexpand-1 '(decompose-num 
		    expr (const foo) (/ goo) ((* +) loo) (t moo)))))
(define-test decompose-bool
  (flet ((dectest (expr)
	   (decompose-bool expr
	     (junctor 'junctor)
	     (literal 'literal)
	     (t 'other))))
    (assert-equal 'literal (dectest 'x))
    (assert-equal 'literal (dectest %(not x)))
    (assert-equal 'junctor (dectest %(and x y)))
    (assert-equal 'other (dectest %(foo bar baz))))
  (assert-equal 42 (decompose-bool true (true 42) (false 3) (t 99))))

(defun split-by-coefficients (exprs &key (op '*) (identity 1))
  (with-collectors (coefficient term)
    (mapc (lambda (expr)
	    (dbind (coefficient term)
		(if (and (consp expr) (eq (fn expr) op) (numberp (arg0 expr)))
		    `(,(arg0 expr) ,(if (cddr (args expr))
					(pcons op (cdr (args expr))
					       (markup expr))
					(arg1 expr)))
		    `(,identity ,expr))
	      (coefficient coefficient)
	      (term term)))
	  exprs)))
(defun dual-decompose (expr op op-identity dual dual-identity)
  (flet ((mksplit (offset exprs)
	   (mvbind (weights terms) 
	       (split-by-coefficients exprs :op dual :identity dual-identity)
	     (values offset weights terms))))
    (cond ((numberp expr) (values expr nil nil))
	  ((not (consp expr)) (values op-identity `(,dual-identity) `(,expr)))
	  ((eq (fn expr) op) (if (numberp (arg0 expr))
				 (mksplit (arg0 expr) (cdr (args expr)))
				 (mksplit op-identity (args expr))))
	  (t (mksplit op-identity `(,expr))))))

(defun split-sum-of-products (expr) (dual-decompose expr '+ 0 '* 1))
(defun split-product-of-sums (expr) (dual-decompose expr '* 1 '+ 0))
(defun split-by-op (expr) 
  (funcall (ecase (fn expr) 
	     (+ #'split-sum-of-products)
	     (* #'split-product-of-sums))
	   expr))

(define-test dual-decompose
  (flet ((ldass (expr o1 ws1 ts1 o2 ws2 ts2)
	   (mvbind (o ws ts) (split-sum-of-products expr)
	     (assert-equal o1 o)
	     (assert-equal ws1 ws)
	     (assert-equal ts1 ts))
	   (mvbind (o ws ts) (split-product-of-sums expr)
	     (assert-equal o2 o)
	     (assert-equal ws2 ws)
	     (assert-equal ts2 ts))))
    (ldass %(+ 1 (* 2 x) (* 3 y z))
	   1 '(2 3) `(x ,%(* y z))
	   1 '(1) `(,%(+ (* 2 x) (* 3 y z))))
    (ldass 42 
	   42 nil nil
	   42 nil nil)
    (ldass %(+ 1 x)
	   1 '(1) '(x)
	   1 '(1) '(x))
    (ldass %(+ x (* y z))
	   0 '(1 1) `(x ,%(* y z))
	   1 '(0) `(,%(+ x (* y z))))
    (ldass 'x 
	   0 '(1) '(x)
	   1 '(0) '(x))
    (ldass %(sin x)
	   0 '(1) `(,%(sin x))
	   1 '(0) `(,%(sin x)))
    (ldass %(* 2 (+ x y) (+ 3 x) (+ x y z))
	   0 '(2) `(,%(* (+ x y) (+ 3 x) (+ x y z)))
	   2 '(0 3 0) `(,%(+ x y) x ,%(+ x y z)))
    (ldass 0
	   0 nil nil
	   0 nil nil)))

;;; macro-writing macro for defining functions as sets of toplevel forms,
;;; each one acting on a different type
(defmacro defdefbytype (defname name)
  `(progn 
     (defvar ,name nil)
     (defmacro ,defname (typematch args &body body)
       `(push (cons ',typematch (lambda ,args ,@body)) ,',name))
     (defun ,name (expr context type)
       (apply (cdr (assoc (icar type) ,name))
	      (if (consp type) `(,expr ,context ,type) `(,expr ,context))))))
