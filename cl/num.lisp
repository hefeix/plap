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

(defun little-epsilon (x) 
  (let* ((x (if (numberp x) x 0))
	 (y (abs x))
	 (v 0.01))
    (if (and (not (equal y 0)) (< y (/ v 2))) (/ y 2) v)))
(defun big-epsilon (x)
  (let* ((x (if (numberp x) x 0)))
    (if (eql x 0) 1 (/ (+ 1 (abs x)) 2))))

(defun dual-num-op (f) (ecase f (* '+) (+ '*)))

;;; replace with identity-element removal
(define-reduction haxx-num-1 (expr)
  :type num
  :condition (and (eq (car expr) '*) (eql (cadr expr) 1))
  :action (if (longerp expr 3) (cons '* (cddr expr)) (caddr expr)))
(define-reduction haxx-num-2 (expr)
  :type num
  :condition (and (eq (car expr) '+) (eql (cadr expr) 0))
  :action (if (longerp expr 3) (cons '+ (cddr expr)) (caddr expr)))

(defun ring-op-p (expr) ;true if rooted in + or * or and or or
  (matches (acar expr) (+ * and or)))

(defun cons-cars (expr)
  (if (consp expr)
      (cons (ncons (car expr)) (mapcar #'cons-cars (cdr expr)))
      expr))

;;; expr should be already cons-car'ed
(defun to-maxima (expr)
  (if (atom expr) expr
      (let ((subexprs (mapcar #'to-maxima (cdr expr))))
	(cons (ncons (acase (caar expr)
		       (+ 'maxima::mplus)
		       (* 'maxima::mtimes)
		       (sin 'maxima::%sin)
		       (exp 'maxima::mexp)
		       (log (return-from to-maxima
			      `((maxima::%log) ((maxima::mabs) ,@subexprs))))
		       (t it)))
	      subexprs))))
	    
(defun from-maxima (expr)
  (if (atom expr) expr
      (let ((args (cdr expr)))
	(mkexpr (acase (caar expr)
		  (maxima::mplus '+)
		  (maxima::mtimes '*)
		  (maxima::%sin 'sin)
		  (maxima::mexp 'exp)
		  (maxima::%log (assert (eq 'maxima::mabs (caadr expr)))
				(setf args (cddr expr))
				'log)
		  (t it))
		(mapcar #'from-maxima args)))))

(define-reduction maxima-reduce (expr)
  :type num
  :action
  (from-maxima (maxima::meval*
		`((maxima::$ev)
		  ((maxima::trigsimp)
		   ,(maxima::meval* (to-maxima (cons-cars expr))))))))
