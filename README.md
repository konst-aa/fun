# fun

A collection of scripts and mini-projects, hopefully a few will become something meaningful. See the **rundown** section for a description of what's in this repo, and some projects may have their own [Replit](https://replit.com) that one can fork and experiment with. To run something locally, see the **dependencies section**. Everything here is licensed under the MIT License.

## rundown:
- `autodiff.scm` is a short automatic differentiation library that comes with a repl. Its whole thing is being able to evaluate derivatives at a point, but the derivatives it prints out are in s-exps and can't be further manipulated. To get started, once in the program's repl, run the `:h` command. [Replit](https://replit.com/@konstantin_aa/autodiff)
- `mips-programs` is currently just one mips program (mergesort), because I can't share the other one as it was a class assignment. I use them to test the mips vm.
- `mips-c-vm` is not meant to be presentable, but it works. There is a usage example in the Makefile (in the folder, `make mergesort`). It can run programs programs that write to a 256x512 display that starts at the address where `.data` starts: `0x10010000`. At the moment, the display is only functional on non-nix compilations, so one needs to install SDL2 normally.

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
- `mips-programs` just needs [Mars](https://courses.missouristate.edu/kenvollmar/mars/)
- `mips-c-vm` The VM itself needs gcc, pkg-config, and SDL2. The whole experience requires Chicken Scheme (for the joke of an assembler) and Mars as well. Chibi Scheme also works.

