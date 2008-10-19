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

(defun ring-op-p (expr) ;true if rooted in + or * or and or or
  (matches (fn expr) (+ * and or)))

;; (define-reduction reduce-abs (expr)
;;   :type num
;;   :condition (matches (car expr) (*
;;   :action
	 
(defun num-table (expr vars table)
  (mapcar (lambda (values)
	    (with-bound-values *empty-context* vars values
	      (peval expr *empty-context*)))
	  table))

(defun eliminate-division (expr)
  (flet ((mkexp (expr) `((exp) ((*) -1.0 ((log) ,expr)))))
    (if (atom expr) expr
	(let ((expr (pcons (fn expr) (mapcar #'eliminate-division (args expr))
			   (markup expr))))
	  (if (eq (fn expr) '/)
	      (pcons '* (if (eq (afn (arg0 expr)) '*)
			    (append (args (arg0 expr))
				    (if (eq (afn (arg1 expr)) '*)
					(mapcar #'mkexp (args (arg1 expr)))
					(ncons (mkexp (arg1 expr)))))
			    (cons (arg0 expr) 
				  (if (eq (afn (arg1 expr)) '*)
				      (mapcar #'mkexp (args (arg1 expr)))
				      (ncons (mkexp (arg1 expr)))))))
	      expr)))))

(defparameter *plop-root-dir* "/Users/madscience/work/plap/trunk/cl")
(labels
    ((read-stream (fname &aux res)
       (with-open-file (stream (concatenate 'string *plop-root-dir* "/" fname))
	 (do ((expr (read stream nil) (read stream nil))) ((null expr))
	   (push (sexpr2p expr) res)))
       (nreverse res))
     (sexprs-size (sexprs) (reduce #'+ sexprs :key #'expr-size))
     (mismatch (n1 n2)
       (if (eq 'nan n2)
	   (not (eq 'nan n1))
	   (and (not (eq 'nan n1))
		(> (/ (abs (- (abs n1) (abs n2)))
		      (+ 0.01 (abs n1) (abs n2))) 0.01)))))
  (let* ((raw-sexprs (read-stream "sample_real_trees_10k"))
	 (raw-nodiv-sexprs (mapcar #'eliminate-division raw-sexprs))
	 (combo-sexprs (read-stream "combo_sexprs"))
	 (combo-nodiv-sexprs (mapcar #'eliminate-division combo-sexprs)))
    (defun test-reducer (reducer &key quick &aux exprs  (mmm 0)
			 (orig (mapcar #'copy-tree raw-nodiv-sexprs))
			 (nums (mesh '(5 5 5) '(0.1 3.0 100.0)
				     '(1.0 6.0 10000.0))))
      (format t "timing info for ~S on 10K exprs:" reducer)
      (time (setf exprs (mapcar (lambda (x) (funcall reducer x))
				raw-nodiv-sexprs)))
      (format t "original size: ~S~%" (sexprs-size raw-sexprs))
      (format t "original nodiv size: ~S~%" (sexprs-size raw-nodiv-sexprs))
      (format t "combo size:    ~S~%" (sexprs-size combo-sexprs))
      (format t "combo nodiv:   ~S~%" (sexprs-size combo-nodiv-sexprs))
      (format t "plop size:     ~S~%" (sexprs-size exprs))
      (unless quick
;; 	(mapc (lambda (x y z) (if (< (expr-size x) (expr-size y))
;; 				  (print* (expr-size x) (expr-size y) x y z)))
;; 	      combo-nodiv-sexprs exprs raw-nodiv-sexprs)
	(mapc (lambda (x y) 
		(assert (equalp (p2sexpr x) (p2sexpr y)) () 
			"maxima munged ~S to ~S" x y))
	      orig raw-nodiv-sexprs)
	(mapc (lambda (x y)
		(if (= 0 (mod (incf mmm) 200)) (print* 'done mmm))
		(handler-case 
		    (let ((t1 (num-table x '(x1 x2 x3) nums))
			  (t2 (num-table y '(x1 x2 x3) nums)))
		      (when (some #'mismatch t1 t2)
			(bind-collectors (v1 v2)
			    (mapc (lambda (a b) (when (mismatch a b)
						  (v1 a) (v2 b)))
				  t1 t2)
			  (format t "mismatch: ~S~%          ~S~%~S~%~S~%" 
				  (p2sexpr x) (p2sexpr y)
				  (delete-duplicates v1)
				  (delete-duplicates v2)))))
		  (system::simple-type-error () 
		    (format t "failed on ~S -> ~S~%" x y))))
	      raw-nodiv-sexprs exprs))
      nil)
    (defparameter raww raw-sexprs)
    (defparameter raww-nodiv raw-nodiv-sexprs)))
;;     (mapcar (lambda (x) 
;; 	      (print* 'foobash x) 
;; 	      (reduct x *empty-context* num))
;; 	    raw-sexprs)))
