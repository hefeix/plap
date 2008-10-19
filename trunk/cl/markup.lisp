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

(defconstant simp 'simp) ; for simplified subexpressions
(defconstant canon 'canon) ; for canonical form subexpressions
(defconstant munged 'munged) ; for subexpressions that have been destuctively
			     ; modified, possibly invalidating their markup

(defun markup (expr) (cdar expr))

(let ((unused (gensym)))
  (defun markp (tag expr) 
    (not (eq (getf (markup expr) tag unused) unused))))

(defun mark (tag expr) (getf (markup expr) tag))
(defun set-mark (tag expr value) (setf (getf (cdar expr) tag) value))
(defsetf mark set-mark)

(defun unmark (tag expr)
  (remf (cdar expr) tag)
  expr)

(defun clear-simp (expr &optional exceptions) ; exceptions must be sorted 
  (setf (mark simp expr)
	(if exceptions
	    (delete-if (lambda (rule) 
			 (and (eq (acar exceptions) rule)
			      (progn (setf exceptions (cdr exceptions)) t)))
		       (mark simp expr))
	    nil)))
(defun mark-simp (expr rule)
  (setf (mark simp expr)
	(insert-if (lambda (rule2)
		     (when (eq rule rule2)
		       (return-from mark-simp expr)) ; no need to modify
		     (string> rule2 rule))
		   rule (mark simp expr))))

(defun simpp (expr rule)
  (awhen (mark simp expr)
    (find rule it)))


(defun canon-expr (cexpr) (car (mark canon cexpr)))
(defun set-canon-expr (cexpr expr) (rplaca (mark canon cexpr) expr))
(defsetf canon-expr set-canon-expr)

(defun canon-parent (cexpr) (cdr (mark canon cexpr)))
(defun set-canon-parent (cexpr expr) (rplacd (mark canon cexpr) expr))
(defsetf canon-parent set-canon-parent)

;; cons in canonical form - doesn't work for lambdas
(defun ccons (fn args expr)
  (assert (not (eq fn 'lambda)))
  (aprog1 (pcons fn args (list canon (ncons expr)))
    (mapc (lambda (arg) (when (consp arg)
			  (if (mark canon arg)
			      (set-canon-parent arg it)
			      (setf (mark canon arg) (cons arg it)))))
	  (args it))))

(defun ccons-lambda (args body expr)
  (aprog1 (pcons 'lambda (list (mklambda-list args) body)
		 (list canon (ncons expr)))
    (mapc (lambda (arg) (when (consp arg)
			  (if (mark canon arg)
			      (set-canon-parent arg it)
			      (setf (mark canon arg) (cons arg it)))))
	  (args it))))
