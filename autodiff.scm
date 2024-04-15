;;; Konstantin Astafurov's automatic differentiation program
;;; R5RS Scheme compatible

(import (srfi 1))

(define (print . args)
  (map display args))

(define (println . args)
  (map display args)
  (newline))

(define (fn f)
  (car f))
;; Accessors
(define (x1 f)
  (cadr f))
(define (x2 f)
  (caddr f))
(define (rest f)
  (cddr f))

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

;; feels shoddy. I'll come up with proper abstractions later,
;; this one is likely premature
(define (transform-sexpr l f post)
  (if (pair? l)
    (post (map (lambda (l) (rec-transform l f post))
               l))
    (f l)))

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
  (define (post l)
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
  (rec-transform l (lambda (x) x) post))

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
     (println ":f (f args ...) = (s-expression) - define a function")
     (println "    example: :f (g x y) = (* 2 x y)")
     (println "    [defines a function g(x, y) = 2xy]")
     (newline)
     (println ":d f wrt - differentiate an existing function f with respect to wrt")
     (println "    example: :d g x [differentiates g(x, y) with respect to x]")
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
    ((:f)
     (let* ((sig (read))
            (vars (cdr sig))
            (_equals (read))
            (def (read)))
       (set! symbol-table (cons `(,(car sig) . (,vars ,def)) symbol-table))))
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
    ((:e)
     (let* ((sexp (read))
            (info (saferef (car sexp) cont))
            (vars (car info))
            (diffed (cadr info))
            (deriv-lambda (eval `(lambda ,vars ,diffed)))
            (res (apply deriv-lambda (cdr sexp))))
       (println res)))
    ((:l)
     (println "Symbol table: " symbol-table))
    (else (println "Unknown command, try :help"))))

(define (main)
  (call/cc top-level!)
  (main))

(println "Welcome! write :help or :h for help, :exit to exit.")
(println "Available functions: + - * / expt exp sqrt sin cos")
(main)
