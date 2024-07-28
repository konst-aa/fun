# fun

A collection of scripts and mini-projects, hopefully a few will become something meaningful. See the **rundown** section for a description of what's in this repo, and some projects may have their own [Replit](https://replit.com) that one can fork and experiment with. To run something locally, see the **dependencies section**. Everything here is licensed under the MIT License.

## rundown:
- `autodiff.scm` is a short automatic differentiation library that comes with a repl. Its whole thing is being able to evaluate derivatives at a point, but the derivatives it prints out are in s-exps and can't be further manipulated. To get started, once in the program's repl, run the `:h` command. [Replit](https://replit.com/@konstantin_aa/autodiff)

## dependencies:
- `autodiff.scm` is R5RS compliant except for its use of `#!eof`. I run it with [Chicken Scheme](http://www.call-cc.org/), which is what my [replit for it](https://replit.com/@konstantin_aa/autodiff?) uses as well. [Gambit](https://gambitscheme.org/) is also a fantastic option, and it has a [web version](https://try.gambitscheme.org/), though it makes the autodiff repl look weird, so it needs the following patch:
```scheme
;; Patch for running on try.gambitscheme.org
;; Replace the readrepl function with this one.
(define (readrepl)
  (display ">> ")
  (flush-output-port) ; flush port to make sure the prompt is displayed
  (read))
```

