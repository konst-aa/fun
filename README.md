# fun

A collection of scripts and mini-projects, maybe some of these will become something meaningful. Everything here is licensed under the MIT license.

## rundown:
- `autodiff.scm` is a short automatic differentiation library that comes with a repl. Its whole thing is being able to evaluate derivatives at a point, but the derivatives it prints out are in s-exps and are unsimplified.

## dependencies:
- `autodiff.scm` *should* be R5RS compliant, so it *should* work on any R5RS Scheme. I'd recommend [chicken](http://www.call-cc.org/) as I am most familiar with it. I made a [replit for it too](https://replit.com/@konstantin_aa/autodiff?). [Gambit](https://gambitscheme.org/) is also a fantastic option, and it has a [web version](https://try.gambitscheme.org/), though it makes the autodiff repl look weird, so it needs the following patch:
```scheme
;; Patch for running on try.gambitscheme.org
;; Replace the readrepl function with this one.
(define (readrepl)
  (display ">> ")
  (flush-output-port) ; flush port to make sure the prompt is displayed
  (read))
```

