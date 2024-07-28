(cond-expand
  (chibi (import (scheme small)))
  (else))

(cond-expand
  (chicken 
    (import (chicken process-context)))
  (chibi 
    (import (scheme process-context))
    (define (command-line-arguments)
      (cdr (command-line))))
  (else))

(import (srfi 1))



(define file 
  (open-input-file (car (command-line-arguments))))

(define (read-string port)
  (define (helper acc)
    (let ((char (read-char port)))
      (if (eof-object? char)
        (list->string (reverse acc))
        (helper (cons char acc)))))
  (helper (list)))
(define contents (read-string file))

(define (make-sport start)
  (list start))

(define (sport-pos sport)
  (car sport))

(define (sport-pos-set! sport new)
  (set-car! sport new))

(define (sport-copy sport)
  (list (sport-pos sport)))

(define (repeat elem n)
  (unfold (lambda (x) (> x n))
          (lambda (x) x)
          (lambda (x) (+ x 1))
          1))
;; 00420820

(define (number->bytestring n bytes)
  ;; convert to base 16
  (let* ((hex (number->string n 16))
         (l (string-length hex))
         (binary-chars (string-append (make-string (- bytes l) #\0) hex))
         (acc (list)))
    (do ((curr (string->list binary-chars) (drop curr 2)))
        ((null? curr) (list->string acc))
        (set! acc (cons (integer->char (string->number (list->string (take curr 2)) 16))
                        acc)))))

(define (sport-read-char sport)
  (if (null? (sport-pos sport))
    (eof-object)
    (let ((char (car (sport-pos sport))))
      (sport-pos-set! sport (cdr (sport-pos sport)))
      char)))

(define file-sport (make-sport (string->list contents)))
; (define (while pred)
;   (lambda (acc port)
;     (do ((curr port (read-char curr))
;          (state acc (pred curr state)))
;         ((car state) (cdr state)))))

;; (list res err-flag)
(define pr-res car)
(define pr-set-res! set-car!)
(define pr-err? cadr)
(define make-pr list)

; (define (parse-char c)
;   (lambda (sport)
;     (let ((parsed (sport-read-char sport)))
;       (if (equal? parsed c)
;         (make-pr c #f)
;         (make-pr "Failed to hit char" #t)))))

(define (parse-pred pred?)
  (lambda (sport)
    (let ((parsed (sport-read-char sport)))
      (if (pred? parsed)
        (make-pr parsed #f)
        (make-pr "Failed to hit char" #t)))))

(define (parse-char c)
  (parse-pred (lambda (parsed)
                (equal? c parsed))))


(define (comb-try parser)
  (lambda (sport)
    (let* ((attempt (sport-copy sport))
           (pr (parser attempt)))
      (if (not (pr-err? pr))
        (sport-pos-set! sport (sport-pos attempt))
        )
      pr
      ;pr
      )))

(define (null-pr-success) (make-pr (list) #f))
(define (null-pr-failure) (make-pr "NULL" #t))

(define (comb-or . parsers)
  (lambda (sport)
    (define (fold-proc parser acc)
      (if (pr-err? acc)
        ((comb-try parser) sport)
        acc))
    (fold fold-proc (null-pr-failure) parsers)))

(define (parse-chars chars)
  (apply comb-or (map parse-char chars)))

(define (comb-greedy parser)
  (lambda (sport)
    (define (loop acc)
      (let ((pr ((comb-try parser) sport)))
        (if (pr-err? pr)
          (reverse acc)
          (loop (cons (pr-res pr) acc)))))
    (make-pr (loop (list)) #f)))

(define (comb-and . parsers)
  (lambda (sport)
    (define (fold-proc parser acc)
      (if (pr-err? acc)
        acc
        (let ((pr ((comb-try parser) sport)))
          (make-pr (cons (pr-res pr) (pr-res acc)) (pr-err? pr)))))
    (let ((pr (fold fold-proc (null-pr-success) parsers)))
      (make-pr (reverse (pr-res pr)) (pr-err? pr)))))

; (define (comb-and* transform . parsers)
;   (lambda (sport)
;     (transform ((apply comb-and parsers) sport))))

(define (compose f g)
  (lambda (x)
    ; (fold (lambda (acc f) (f acc)) x funcs)
    (f (g x))
    ))

(define (comb-transform parser transform)
  (lambda (sport)
    (let ((pr (parser sport)))
      (if (pr-err? pr)
        pr
        (make-pr (transform (pr-res pr)) #f)))))

(define (comb-and* . parsers)
  (comb-transform (apply comb-and parsers)
                  (lambda (pr)
                    (filter (compose not null?) pr))))

(define (comb-greedy* . parsers)
  (comb-transform (apply comb-greedy parsers)
                  (lambda (pr)
                    (filter (compose not null?) pr))))

; (define (comb-greedy* . parsers)
;   (comb-transform (apply comb-greedy aprsers)
;                   (filter (compose not null?) parsers)))

(define (comb-flatten parser)
  (comb-transform parser (lambda (lst) (apply append lst))))

(define (comb-null parser)
  (comb-transform parser (lambda (_) (list))))

(define (comb-into-symbol parser)
  (comb-transform parser (lambda (pr) (string->symbol (list->string pr)))))

(define parse-alpha
  (parse-chars (string->list "abcdefghijklmnopqrstuvwxyz")))

(define parse-digit
  (parse-chars (string->list "1234567890")))

(define parse-hex-digit
  (parse-chars (string->list "12345678910ABCDEF")))
(define parse-b10
  (comb-transform
    (comb-greedy* parse-digit)
    (lambda (pr)
      (string->number (list->string pr)))))

(define parse-whitespace
  (parse-chars '(#\space #\tab)))


(define WHITESPACE '(#\space #\tab #\newline))
(define (member-pred lst)
  (lambda (char)
    (member char lst)))

; (define take-non-whitespace
;   (take-chars (lambda (char) (not (member char WHITESPACE)))))

; (define until-non-whitespace
;   (take-chars (member-pred '(#\space #\tab #\newline))))

(define (comb-discard parser)
  (lambda (sport)
    (parser sport)))

(define parse-alpha
  (parse-chars (string->list "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVEWXYZ")))

(define parse-eol
  (comb-greedy* (comb-null (parse-chars WHITESPACE))))

(define (parse-1ormore parser)
  (comb-and parser (comb-greedy parser)))

(define (parse-string s)
  (apply comb-and (map parse-char (string->list s))))

(define parse-label-name
  (comb-into-symbol
    (comb-greedy
      (comb-or parse-alpha (parse-chars (string->list "_"))))))

(define parse-type
  (comb-into-symbol (comb-or (parse-string ".word")
                             (parse-string ".space"))))

(define (comb-endswith parser term-parser)
  (lambda (sport)
    (let ((tpr ((comb-try term-parser) sport)))
      (if (pr-err? tpr)
        (parser sport)
        (make-pr (pr-res tpr) #t)))))

(define parse-hex
  (comb-flatten
    (comb-and*
      (comb-null (parse-char #\0))
      (comb-null (parse-char #\x))
      (comb-transform
        (comb-greedy* parse-hex-digit)
        (lambda (pr)
          (string->number (list->string pr) 16))))))

(define parse-word
  (comb-or (comb-flatten (comb-and* parse-b10
                                    (comb-null (parse-chars WHITESPACE))))
           (comb-flatten (comb-and* parse-hex (comb-null (parse-chars WHITESPACE))))))


(define parse-label
  (comb-and*
    (comb-flatten (comb-and* parse-label-name
                             parse-eol
                             (comb-null (parse-char #\:))))
    parse-eol
    parse-type
    (comb-flatten (comb-greedy* (comb-and* parse-eol parse-word)))))


(define parse-comment
  (comb-null (comb-and* (parse-char #\#)
                        (comb-greedy (parse-pred
                                       (lambda (char) (not (equal? char #\newline))))))))
(define parse-data
  (comb-and* (comb-into-symbol (parse-string ".data"))
             (comb-greedy*
               (comb-or
                 (comb-and* parse-eol parse-comment)
                 (comb-flatten (comb-and* parse-eol parse-label))))))


; (define parse-all
;   (comb-greedy*))


; (display (pr-res (parse-data file-sport)))

; (newline)
; (parse-eol file-sport)
; (newline)
; (parse-eol file-sport)
; (display (parse-label file-sport))
; (newline)
; (parse-eol file-sport)
; (display (parse-label file-sport))
; (newline)
; (write (parse-eol file-sport))
; (write ((comb-and parse-label (parse-char #\:)) file-sport))
; (write ((comb-greedy (comb-or parse-alpha parse-whitespace)) file-sport))

(define DATA-OFFSET (string->number "10010000" 16))
; (define addr-table (list))
(define label-table (list))
(define (alist-ref x lst) (cdr (assoc x lst)))

;; (varName type numbers)
(define get-label car)
(define get-type cadr)
(define get-numbers caddr)


(define (data-bitstring directives)
  (define addr DATA-OFFSET)
  (define acc "")
  (do ((directives directives (cdr directives)))
      ((null? directives) acc)
      (let* ((curr (car directives))
             (label (get-label curr))
             (numbers (get-numbers curr)))
        (set! label-table `((,label . ,addr) . ,label-table))
        (case (get-type curr)
          ((.space)
           (let* ((size (car numbers))
                  (bytestring (make-string size #\0)))
             (set! acc (string-append acc bytestring))
             (set! addr (+ addr size))
             ))
          ((.word)
           (let* ((size (* 4 (length numbers)))
                  (bytestring (apply string-append
                                     (map (lambda (n)
                                            (number->bytestring n 8))
                                          numbers))))
             (set! acc (string-append acc bytestring))
             (set! addr (+ addr size))
             )))
        )
      )
  )

(define outfile (open-output-file "mips-data"))
(define data-res (pr-res (parse-data file-sport)))
; (display data-res)
(display (data-bitstring (cadr data-res)) outfile)

; ; (display (number->byte-string 4327456) outfile)
; (display (number->byte-string 4327456 4) outfile)


