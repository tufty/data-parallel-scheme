;; Compiler back end.

;; We deal with a language which is already typed and reduced
;; Given the impedance mismatch between Scheme's full number stack and
;; the underlying layer's meagre builtins, we will, for the moment, go with
;; meagre types.  Yeah, it sucks.

;; type          := atomic-type | lambda-type
;; scalar-type   := intrinsic-type | void | any
;; atomic-type   := <scalar-type : count>
;; lambda-type   := <type ... -> type>
;;
;; expr          := const-expr | var-expr | lambda-expr | sel-expr |
;;                  let-expr | seq-expr | app-expr
;; const-expr    := value
;; var-expr      := symbol
;; lambda-expr   := (lambda lambda-type (var-expr ...) expr)
;; sel-expr      := (select type expr const-expr const-expr)
;; let-expr      := (let (var-expr type expr) expr)
;; seq-expr      := (begin expr expr)
;; app-expr      := (expr expr ...)
