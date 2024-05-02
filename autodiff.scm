;;; Konstantin Astafurov's automatic differentiation program
;;; R5RS Scheme compatible

(import (srfi 1))

;;; Debugging
(define (print . args)
  (map display args))

(define (println . args)
  (map display args)
  (newline))

(define (print-list l)
  (map println l))


;; Accessors

(define (fn f)
  (car f))
(define (x1 f)
  (cadr f))
(define (x2 f)
  (caddr f))
(define (rest f)
  (cddr f))

;;; Heavy lifting
(define (deriv f)
  ;; treat (x1 f) as x
  (case (car f)
    ((expt)
     `(* ,(x2 f) (expt ,(x1 f) ,(- (x2 f) 1))))
    ((exp)
     `(exp ,(x1 f)))
    ((sqrt)
     (deriv `(expt ,(x1 f) 0.5)))
    ((sin)
     `(cos ,(x1 f)))
    ((cos)
     `(- (sin ,(x1 f))))))

(define (diff f wrt)
  (define (chain f g)
    `(* ,(deriv f)
      ,(diff g wrt)))
  (cond
    ((eq? wrt f) 1)
    ((and (pair? f)
          (null? (cddr f))
          (member (car f) '(* + /)))
     (case (car f)
       ((+ *)  ; identity ops: (* x), (+ x), etc.
        (diff (x1 f) wrt))
       ((/)
        (diff `(/ 1 ,(x1 f)) wrt))))
    ((pair? f)
     (case (car f)
       ((+) `(+ ,@(map (lambda (f) (diff f wrt)) (cdr f))))
       ((-) `(- ,(diff `(+ ,@(cdr f)) wrt)))
       ((*) `(+ (* ,(diff (x1 f) wrt) ,@(rest f))
              (* ,(x1 f) ,(diff `(* ,@(rest f)) wrt))))
       ((/) `(/ (- (* ,(diff (x1 f) wrt) ,(x2 f))
                   (* ,(x1 f) ,(diff (x2 f) wrt)))
              (expt ,(x2 f) 2)))
       (else
         ;; does the heavy lifting
         (chain f (x1 f)))
       ))
    (else 0)))

;;; Simplifying expressions:
(define (rec-transform t l)
  ;; feels shoddy. I'll come up with proper abstractions later,
  ;; this one is likely premature.
  ;; Also, this might need better control flow, but not yet.
  (if (pair? l)
    (t (map (lambda (nl) (rec-transform t nl)) l))
    l))

(define (prune-identities l)
  (define (eval-identity-ops identity-num l)
    (let* ((pruned (filter
                     (lambda (x) (or (not (number? x)) (not (= x identity-num))))
                     (cdr l)))
           (num-args (length pruned)))
      (cond
        ((= num-args 0) identity-num)
        ((= num-args 1) (car pruned))
        (else `(,(fn l) ,@pruned)))))
  (define (transform l)
    (case (fn l)
      ((+ -)
       (eval-identity-ops 0 l))
      ((*)
       (if (member 0 l)
         0
         (eval-identity-ops 1 l)
         ))
      ((/)
       ;; ignore div by 0 even though we can catch it here
       ;; why bother?
       (cond
         ((= (x1 l) 0) 0)
         ((= (x2 l) 1) (x1 l))
         (else l)))
      ((exp)
       (if (= (x1 l) 0)
         1
         l))
      ((expt)
       (cond
         ((= (x2 l) 0) 1)
         ((= (x2 l) 1) (x1 l))
         (else l)))
      (else l))
    )
  (rec-transform transform l))

(define (collapse-literals l)
  (define (transform l)
    (let ((op (fn l)))
      (if (and (every number? (cdr l))
               (member op '(+ * -)))
        (eval l)
        l)))
  (rec-transform transform l))

;;; Other operations

;;; this *should* work
(define (compose . args)
  (lambda (x)
    (let ((acc x))
      (do ((args (reverse args) (cdr args)))
          ((null? args) acc)
          (set! acc ((car args) acc))))))

(define full-prune (compose prune-identities collapse-literals))

(define (symbolic-call sym)
  (lambda args
    `(,sym ,@args)))

(define (gradient f vars)
  (map (lambda (v) (prune-identities (diff f v))) vars))

(define (dot a b)
  (apply + (map * a b)))

(define (symbolic-dot a b)
  (full-prune `(+ ,@(map (symbolic-call '*) a b))))

(define (symbolic-mag v)
  (full-prune `(sqrt (+ ,@(map (symbolic-call '*) v v)))))

(define (symbolic-normalize v)
  (let ((c (symbolic-mag v)))
    (map (lambda (x) `(/ ,x ,c)) v)))

(define (mag v)
  (sqrt (apply + (map * v v))))

(define (normalize v)
  (let ((c (mag v)))
    (map (lambda (x) (/ x c)) v)))

(define (symbolic-hessian f vars)
  (full-prune (map (lambda (d) (gradient d vars))
                   (gradient f vars))))

(define (readrepl)
  (display ">> ")
  (read))

(define (readp prompt)
  (println prompt)
  (readrepl))

(define symbol-table (list))

(define (saferef val cont)
  (let ((maybe-val (assoc val symbol-table)))
    (cond
      ((eq? maybe-val #f) ; fun fact: (null? #f) is #f, only (null? '()) is #t
       (println "Symbol missing, try calling :l to list all symbols")
       (cont (list)))
      (else (cdr maybe-val)))))

(define (top-level! cont)
  (case (readrepl)
    ((:help :h)
     (newline)
     (println "Available functions: + - * / expt exp sqrt sin cos")
     (newline)
     (println ":dot (x1 x2 x3 ...) (y1 y2 y3 ...) - calculate the dot product")
     (newline)
     (println ":norm (x1 x2 x3) - normalize a vector")
     (newline)
     (println ":f (f args ...) = (s-expression) - define a function")
     (println "    example: :f (g x y) = (* 2 x y)")
     (println "    [defines a function g(x, y) = 2xy]")
     (newline)
     (println ":d f wrt - differentiate an existing function f with respect to wrt")
     (println "    example: :d g x [differentiates g(x, y) with respect to x]")
     (newline)
     (println ":g f - compute the gradient of f")
     (println "    example: :g g [computes the gradient of g(x, y)]")
     (newline)
     (println ":eg (grad-g args ...) - evaluate the gradient grad-g at point (args ...)")
     (newline)
     (println ":hessian f - compute the hessian of f")
     (newline)
     (println ":eh (hess-f args ...) - evaluate the hessian hess-f at point (args ...)")
     (newline)
     (println ":e (da/db args ...) - evaluate the derivative da/db at point (args ...)")
     (newline)
     (println ":l - list all functions in the symbol table")
     (newline)
     (println ":exit - exit"))
    ((:exit #!eof)
     (newline)
     (println "Goodbye!")
     (exit))
    ((:dot)
     (let* ((a (read))
            (b (read)))
       (println (symbolic-dot a b))))
    ((:norm)
     (let* ((v (read)))
       (println (symbolic-normalize v))))
    ((:f)
     (let* ((sig (read))
            (vars (cdr sig))
            (_equals (read))
            (def (read)))
       (set! symbol-table (cons `(,(car sig) . (,vars ,def)) symbol-table))))
    ((:g)
     (let* ((f (read))
            (info (saferef f cont))
            (vars (car info))
            (grad (gradient (cadr info) vars))
            (grad-name (string-append "grad-" (symbol->string f)))
            (grad-sym (string->symbol grad-name)))
       (apply println "Gradient: " `((,grad-sym . ,vars) " = " ,grad))
       ;; weaving in a `list` so a future lambda made with `eval`
       ;; will not try to evaluate (x y z) as a function call
       (set! symbol-table (cons `(,grad-sym . (,vars (list ,@grad))) symbol-table))
       (println "Saved gradient in symbol table (use :l to list)")))
    ((:eg)
     (let* ((sexp (read))
            (info (saferef (car sexp) cont))
            (vars (car info))
            (grad (cadr info))
            (grad-lambda (eval `(lambda ,vars ,grad)))
            (res (apply grad-lambda (cdr sexp))))
       (println res)))
    ((:d)
     (let* ((f (read))
            (wrt (read))
            (info (saferef f cont))
            (diffed (prune-identities (diff (cadr info) wrt)))
            (vars (car info))
            (deriv-name (string-append "d" (symbol->string f)
                                       "/d" (symbol->string wrt)))
            (deriv-sym (string->symbol deriv-name)))
       (apply println "Derivative: " `((,deriv-sym . ,vars) " = " ,diffed))
       (set! symbol-table (cons `(,deriv-sym . (,vars ,diffed)) symbol-table))
       (println "Saved derivative in symbol table (use :l to list)")))
    ((:hessian)
     (let* ((f (read))
            (info (saferef f cont))
            (vars (car info))
            (hess (symbolic-hessian (cadr info) vars))
            (hess-name (string-append "hess-" (symbol->string f)))
            (hess-sym (string->symbol hess-name)))
       (apply println "Hessian: " `((,hess-sym . ,vars) " ="))
       (print-list hess)
       ;; weaving in a `list` so a future lambda made with `eval`
       ;; will not try to evaluate (x y z) as a function call
       (set! symbol-table 
         (cons `(,hess-sym . (,vars (list ,@(map (lambda (l) `(list . ,l)) hess))))
               symbol-table))
       (println "Saved hessian in symbol table (use :l to list)")))
    ((:eh)
     (let* ((sexp (read))
            (info (saferef (car sexp) cont))
            (vars (car info))
            (hess (cadr info))
            (hess-lambda (eval `(lambda ,vars ,hess)))
            (res (apply hess-lambda (cdr sexp))))
       (print-list res)))
    ((:e)
     (let* ((sexp (read))
            (info (saferef (car sexp) cont))
            (vars (car info))
            (diffed (cadr info))
            (deriv-lambda (eval `(lambda ,vars ,diffed)))
            (res (apply deriv-lambda (cdr sexp))))
       (println res)))
    ((:l)
     (println "Symbol table: ")
     (print-list symbol-table))
    (else (println "Unknown command, try :help"))))

(define (main)
  (call/cc top-level!)
  (main))

(println "Welcome! write :help or :h for help, :exit to exit.")
(println "Available functions: + - * / expt exp sqrt sin cos")
(main)
