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

(define-constant +largest-exp-arg+ 80.0)
(define-constant +smallest-log-arg+ 0.0001)

(defun convert-bool-atom (atom) (ecase atom ((t) true) ((nil) false)))
(labels ((find-mapper (type)
	   (if (atom type)
	       (if (eq type bool) #'convert-bool-atom nil)
	       (when (eq (car type) 'list) 
		 (awhen (find-mapper (cadr type))
		   (bind #'mapcar it /1))))))
  (defun convert-bools (value type-fn)
    (if (lambdap value) 
	value
	(aif (find-mapper (funcall type-fn)) (funcall it value) value))))

(macrolet 
    ((eval-with (eval-name others &body body)
       `(let ((eval-fn ,eval-name))
	  (labels ((and-op (args) (and (funcall eval-fn (car args))
				       (aif (cdr args) (and-op it) t)))
		   (or-op (args) (or (funcall eval-fn (car args))
				     (aif (cdr args) (or-op it) nil)))
		   (call (op args)
		     (case op
		       (and (and-op args))
		       (or (or (not args) (or-op args)))
		       (not (not (funcall eval-fn (car args))))

		       (+ (reduce #'+ args :key eval-fn))
		       (* (reduce #'* args :key eval-fn))
		       (exp (let ((result (funcall eval-fn (car args))))
			      (if (> result +largest-exp-arg+)
				  (throw 'nan 'nan)
				  (exp result))))
		       (log (let ((arg (abs (funcall eval-fn (car args)))))
			      (if (< arg +smallest-log-arg+) 
				  (throw 'nan 'nan)
				  (log arg))))
		       (sin (sin (funcall eval-fn (car args))))

		       (tuple (apply #'vector args))
	       
		       (if (funcall eval-fn (if (funcall eval-fn (car args))
					      (cadr args)
					      (caddr args))))

		       ,@others)))
	    ,@body)))
     (with-error-handling (name result type-fn)
       `(progn
	  (handler-case 
	      (catch 'nan 
		(return-from ,name (convert-bools ,result ,type-fn)))
	    #+clisp(system::simple-floating-point-overflow ())
	    #+clisp(system::simple-arithmetic-error ())
	    (division-by-zero ()))
	  'nan)))
  ;;; peval-cl behaves like peval, only bools evaluate to t/nil instead
  ;;; of true/false, and doesn't do error handling
  (defun peval-cl (expr context)
    (eval-with (bind #'peval-cl /1 context)
	       ((list (mapcar eval-fn args))
		(append (apply #'nconc (mapcar eval-fn args)))
		(lambda expr)
		(t (apply op (mapcar eval-fn args))))
	       (cond ((consp expr) (call (fn expr) (args expr)))
		     ((symbolp expr) (case expr 
				       (true t)
				       (false nil)
				       (nan 'nan)
				       ((nil) nil)
				       (t (acase (getvalue expr context)
						 (true t)
						 (false nil)
						 (t it)))))
		     (t expr))))
  (defun pfuncall (fn args)
    (eval-with (lambda (value) (unless (eq value 'false) value))
	       ((list args) (t (apply fn args)))
	       (with-error-handling pfuncall (call fn args) 
				    (funcall-type fn args))))
  (defun peval (expr &optional (context *empty-context*) type)
    (with-error-handling peval (peval-cl expr context)
			 (lambda () (or type (expr-type expr context))))))
(define-all-equal-test peval
    (list (list false (list %(and true false)
			    %(or false false)
			    %(and false true)))
	  (list 4 (list %(+ 1 1 1 1) 
			%(* 2 2)))))

(defun papply (fn context &rest args)
  (apply #'apply #'pfuncall fn context args)) ;just beautiful...
