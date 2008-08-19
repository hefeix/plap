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

;;; eval-subexpr behaves like eval-expr, only bools evaluate to t/nil instead
;;; of true/false
(defun eval-subexpr (expr context)
  (labels ((and-op (args) (and (eval-subexpr (car args) context)
			       (aif (cdr args) (and-op it) t)))
	   (or-op (args) (or (eval-subexpr (car args) context)
			     (aif (cdr args) (and-op it) nil)))
	   (call (op args)
	     (case op
	       (and (and-op args))
	       (or (or (not args) (or-op args)))
	       (not (not (eval-subexpr (car args) context)))

	       (+ (reduce #'+ args :key (bind #'eval-subexpr /1 context)))
	       (* (reduce #'* args :key (bind #'eval-subexpr /1 context)))
	       (exp (exp (eval-subexpr (car args) context)))
	       (log (let ((arg (eval-subexpr (car args) context)))
		      (if (< arg 0.01) most-positive-single-float (log arg))))
	       (sin (sin (eval-subexpr (car args) context)))
	       (t (apply (symbol-function op) 
			 (mapcar (bind #'eval-subexpr /1 context) args))))))
    (cond ((consp expr) (call (car expr) (cdr expr)))
	  ((symbolp expr) (case expr 
			    (true t)
			    (false nil)
			    (nan 'nan)
			    (nil nil)
			    (t (acase (get-value expr context)
				 (true t)
				 (false nil)
				 (t it)))))
	  (t expr))))

(defun eval-expr (expr &optional context type)
  (aif (eval-subexpr expr context)
       (if (eq it t) 'true it)
       (if (eq (or type (expr-type expr context)) bool) 'false)))
(define-all-equal-test eval-expr
    '((false ((and true false) (or false false) (and false true)))
      (4 ((+ 1 1 1 1) (* 2 2)))))
