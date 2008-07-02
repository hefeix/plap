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

(defun canonize (expr &key (type (expr-type expr)) parent)
  (let ((op (if (consp expr) (car expr)))
	(ops '(exp log sin))
	(op-offsets '(0 1 0)))
    (labels
	((canonize-children (expr)
	   (if (consp expr)
	       (cons (car expr) (mapcar (bind #'canonize /1 :parent op ;fixme
					      :type (or (expr-type /1) type))
					  (cdr expr)))
	       expr))
	 (bool-structure (expr)
	   (if parent 
	       (list (dual-bool-op parent) expr)
	       (list 'or (list 'and) (list 'and expr))))
	 (sub-product (op offset)
	   (list '* 0 (list op
			    (nconc (list '+ offset)
				   (mapcar 
				    (bind #'list '* 0 (list /1 (list '+ /2)))
				    ops op-offsets)))))
	 (rec-split (weight term splitter builder)
	   (multiple-value-bind (o ws ts) (funcall splitter term)
	     (declare (ignore o))
	     (funcall builder weight ws ts)))
	 (dual-assemble (op ops-terms splitter builder o ws ts &optional top)
	   (nconc (list op o) ops-terms
		  (cond 
		    ((or top (longerp ws 1))
		     (nconc (list (funcall builder 0 nil nil))
			    (mapcar (bind #'rec-split /1 /2 splitter builder)
				    ws ts)))
		    (ws (list 
			 (list (dual-num-op op) (car ws)
			       (canonize-children (car ts))))))))
	 (sum-of-products (o ws ts &optional top)
	   (dual-assemble 
	    '+ (mapcar #'sub-product ops op-offsets)
	    #'split-product-of-sums #'product-of-sums o ws ts top))
	  (product-of-sums (o ws ts)
	    (dual-assemble 
	     '* (collecting
		  (mapc (lambda (op offset)
			  (unless (find op ts :key (lambda (x)
						     (and (consp x) (car x))))
			    (collect (list '+ 1 (sub-product op offset)))))
			ops op-offsets))
	     #'split-sum-of-products #'sum-of-products o ws ts)))

;; 	 (sum-of-products (o ws ts &key toplevel)
;; 	   (nconc (list '+ o)
;; 		  (mapcar #'sub-product ops op-offsets)
;; 		  (cond 
;; 		    ((or toplevel (longerp ws 1))
;; 		     (nconc (list (product-of-sums 0 nil nil))
;; 			    (mapcar (bind #'rec-split /1 /2
;; 					  #'split-product-of-sums
;; 					  #'product-of-sums)
;; 				    ws ts)))
;; 		    (ws (list 
;; 			 (list '* (car ws) (canonize-children (car ts))))))))
;; 	 (product-of-sums (o ws ts)
;; 	   (nconc (list '* o)
;; 		  (collecting
;; 		    (mapc (lambda (op offset)
;; 			    (unless (find op ts :key 
;; 					  (lambda (x) (and (consp x) (car x))))
;; 			      (collect (list '+ 1 (sub-product op offset)))))
;; 			  ops op-offsets))
;; 		  (cond 
;; 		    ((longerp ws 1)
;; 		     (nconc (list (sum-of-products 0 nil nil))
;; 			    (mapcar (bind #'rec-split /1 /2
;; 					  #'split-sum-of-products
;; 					  #'sum-of-products)
;; 				    ws ts)))
;; 		    (ws (list
;; 			 (list '+ (car ws) (canonize-children (car ts)))))))))
      (ecase type
	(bool
	 (decompose-bool expr
	   (literal (bool-structure expr))
	   (junctor (let ((body (nconc (list op (list (dual-bool-op op)))
				       (cdr (canonize-children expr)))))
		      (if parent 
			  body 
			  (list (dual-bool-op op) (list op) body))))
	   (t (bool-structure (canonize-children expr)))))
	(num 
	 (multiple-value-bind (o ws ts) (split-sum-of-products expr)
	   (sum-of-products o ws ts t)))))))
(define-test canonize
  ;; boolean cases
  (assert-equal '(or (and) (and x))
		(canonize 'x :type 'bool))
  (assert-equal '(or (and) (and (or) (or x1) (or (not x4)))) 
		(canonize '(and x1 (not x4)) :type 'bool))
  (assert-equal '(and (or) (or (and) (and x1) (and (not x4))))
		(canonize '(or x1 (not x4)) :type 'bool))
  (assert-equal '(or (and) (and x1)) (canonize 'x1 :type 'bool))
  (assert-equal  '(and (or) (or (and) (and (or) (or x1) (or x2)) (and x3)))
		 (canonize '(or (and x1 x2) x3) :type 'bool))
  ;; mixed boolean-numeric and numeric cases
  (let* ((exp-block '(* 0 (exp (+ 0
				(* 0 (exp (+ 0)))
				(* 0 (log (+ 1)))
				(* 0 (sin (+ 0)))))))
	 (log-block '(* 0 (log (+ 1
				(* 0 (exp (+ 0)))
				(* 0 (log (+ 1)))
				(* 0 (sin (+ 0)))))))
	 (sin-block '(* 0 (sin (+ 0
				(* 0 (exp (+ 0)))
				(* 0 (log (+ 1)))
				(* 0 (sin (+ 0)))))))
	 (add-blocks `(,exp-block ,log-block ,sin-block))
	 (mult-block `(* 0
			 (+ 1 ,exp-block)
			 (+ 1 ,log-block)
			 (+ 1 ,sin-block))))
    (assert-equal `(or (and) (and (< (+ 2 ,@add-blocks ,mult-block) 
				     (+ 3 ,@add-blocks ,mult-block))))
		  (canonize '(< 2 3) :type 'bool))
    (assert-equal `(+ 0 ,@add-blocks ,mult-block)
		  (canonize 0))
    (assert-equal `(+ 0 ,@add-blocks ,mult-block
		      (* 1 ,@(cddr mult-block) (+ 0 x)))
		  (canonize 'x :type 'num))
    (assert-equal `(+ 0 ,@add-blocks ,mult-block
		      (* 1
			 (+ 1 ,exp-block)
			 (+ 1 ,log-block)
			 (+ 0 (sin (+ 0 ,@add-blocks ,mult-block
				      (* 1 ,@(cddr mult-block) (+ 0 x)))))))
		  (canonize '(sin x)))
    (assert-equal `(+ 0 ,@add-blocks ,mult-block
		      (* 1 
			 ,@(cddr mult-block) 
			 (+ 0 ,@add-blocks)
			 (+ 0 ,@add-blocks (* 1 x))
			 (+ 0 ,@add-blocks (* 1 y))))
		  (canonize '(* x y)))))
;;   (assert-equal `(+ 0 
;; 		  (* 0 (exp (+ 0)))
;; 		  (* 0 (log (+ 1)))
;; 		  (* 0 (sin (+ 0)))
;; 		  (* 
;; 		   (+ 0 (* 1 x))
;; 		   (+ 1 (* 0 (exp (+ 0))))
;; 		   (+ 1 (* 0 (log (+ 1))))
;; 		   (+ 1 (* 0 (sin (+ 0))))))

;; (+ 0 
;; 		  (* 0 (/ (+ 0) (+ 1)))
;; 		  (* 1 (/ (+ 0 (* 1 x)) (+ 1)))
;; 		  (* 1 (/ (+ 0 (* 1 y)) (+ 1))))
;; 		(canonize '(+ x y))))

;; 		   (+ 1 (* 0 (exp (+ 0))))
;; 		   (+ 1 (* 0 (log (+ 1))))
;; 		   (+ 1 (* 0 (sin (+ 0))))))

(defun loci (fn expr &key (type (expr-type expr)) parents)
  (flet ((boolrec (&optional type)
	   (mapc (bindapp #'loci fn /1 :parents (cons expr parents)
			  (if type (list :type type)))
		 (cdr expr))))
    (ecase type
      (bool
       (decompose-bool expr
	 (literal)
	 (junctor (funcall fn expr parents)
		  (boolrec 'bool))
	 (t (boolrec)))))))
(define-test loci-bool
  (assert-equal '(((and (or x) (or y)))
		  ((or x) (and (or x) (or y)))
		  ((or y) (and (or x) (or y))))
		(collecting (loci (lambda (expr parents) 
					 (collect (cons expr parents)))
				       '(and (or x) (or y))))))
(defun make-replacer-knob (at &rest settings)
  (apply 
   #'vector 
   (cons (let ((original (car at))) (lambda () (rplaca at original)))
	 (mapcar (lambda (setting) (lambda () (rplaca at setting)))
		 settings))))
(defun make-inserter-knob (at &rest settings)
  (apply  
   #'vector
   (let ((set-to nil))
     (cons (lambda () (when set-to
			(aif (cdr set-to)
			     (rplacd (rplaca set-to (car it))
				     (cdr it))
			     (progn (assert (eq (cdr at) set-to))
				    (rplacd at nil)))
			(setf set-to nil)))
	   (mapcar (lambda (setting) 
		     (lambda () 
		       (if set-to
			   (rplaca set-to setting)
			   (rplacd at (setf set-to (cons setting (cdr at)))))))
		   settings)))))
(defun knob-arity (knob) (array-total-size knob))

(defun test-knob (list knob results)
  (dorepeat 100 (let ((n (random 4)))
		  (funcall (elt knob n))
		  (assert-equal (elt results n) list)))
  (funcall (elt knob 0)))
(define-test make-replacer-knob
  (let* ((list (list 1 2 3 4))
	 (knob (make-replacer-knob (cdr list) 'x 'y 'z))
	 (knob2 (make-replacer-knob list 'a 'b 'c))
	 (knob3 (make-replacer-knob (last list) 'p 'd 'q))
	 (res (vector '(1 2 3 4) '(1 x 3 4) '(1 y 3 4) '(1 z 3 4)))
	 (res2 (vector '(1 2 3 4) '(a 2 3 4) '(b 2 3 4) '(c 2 3 4)))
	 (res3 (vector '(1 2 3 4) '(1 2 3 p) '(1 2 3 d) '(1 2 3 q))))
    (test-knob list knob res)
    (test-knob list knob2 res2)
    (test-knob list knob3 res3))
  (let* ((list (list 1))
	 (knob (make-replacer-knob list 'a 'b 'c))
	 (res (vector '(1) '(a) '(b) '(c))))
    (test-knob list knob res)))
(define-test make-inserter-knob
  (let* ((list (list 1 2 3 4))
	 (knob (make-inserter-knob (cdr list) 'x 'y 'z))
	 (knob2 (make-inserter-knob list 'a 'b 'c))
	 (knob3 (make-inserter-knob (last list) 'p 'd 'q))
	 (res (vector '(1 2 3 4) '(1 2 x 3 4) '(1 2 y 3 4) '(1 2 z 3 4)))
	 (res2 (vector '(1 2 3 4) '(1 a 2 3 4) '(1 b 2 3 4) '(1 c 2 3 4)))
	 (res3 (vector '(1 2 3 4) '(1 2 3 4 p) '(1 2 3 4 d) '(1 2 3 4 q))))
    (test-knob list knob res)
    (test-knob list knob2 res2)
    (test-knob list knob3 res3))
  (let* ((list (list 1))
	 (knob (make-inserter-knob list 'a 'b 'c))
	 (res (vector '(1) '(1 a) '(1 b) '(1 c))))
    (test-knob list knob res)))

(defun knobs-at (expr bindings &key (type (expr-type expr)))
  (collecting
    (ecase type
      (bool
       (decompose-bool expr
	 (junctor
	  (let ((tovisit (copy-hash-table (gethash 'bool bindings))))
	    (aif (extract-literal expr)
		 (remhash (litvariable it) tovisit)
		 (mapl (lambda (l)
			 (let ((at (car l)))
			   (awhen (extract-literal at)
			     (assert (junctorp at))
			     (remhash (litvariable it) tovisit)
			     (collect (make-replacer-knob 
				       (cdr at) ; a single knob for:
				       (identity-elem (car at)) ; 1 rm
				       (litnegation it))))))    ; 2 negate
		       (cdr expr)))
	    (maphash-keys (lambda (x)
			    (collect (make-inserter-knob 
				      expr x (litnegation x))))
			  tovisit))))))))
;;       (num
;;        ((* +) (let ((x (cadr expr)))
;; 		(when (numberp x)
;; 		  (let ((e1 (little-epsilon x)) 
;; 			(e2 (big-epsilon x)))
;; 		    (collect (make-replacer-knob (cdr expr) (+ x e1) (- x e1)
;; 						 (- x e2) (+ x e2)))))
;; 		(collect (make-inserter-knob (cdr expr)
		  
