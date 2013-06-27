;; Compiler back end.

;; We deal with a language which is already typed and reduced
;; Given the impedance mismatch between Scheme's full number stack and
;; the underlying layer's meagre intrinsics, we will, for the moment, go with
;; meagre types.  Yeah, it sucks.

;; type          := atomic-type | lambda-type
;; scalar-type   := intrinsic-type | void | any
;; atomic-type   := [scalar-type : count]
;; lambda-type   := [type ... -> type]
;;
;; expr          := const-expr | var-expr | lambda-expr | sel-expr |
;;                  let-expr | seq-expr | app-expr | tail-expr | return-expr
;; const-expr    := value
;; var-expr      := symbol
;; lambda-expr   := (lambda lambda-type (var-expr ...) expr)
;; sel-expr      := (select type expr const-expr const-expr)
;; let-expr      := (let (var-expr type expr) expr)
;; seq-expr      := (begin expr expr)
;; app-expr      := (expr expr ...)
;; tail-expr     := (tail expr expr ...)
;; return-expr   := (return expr)

(define (zip . args)
  (apply map cons* args))

(define (string-interleave separator list)
  (if (null? list) ""
      (fold-left (lambda (acc e) (format "~a, ~a" acc e)) (car list) (cdr list))))

;; Environment handling
(define (env-extend k v e)
  (cons (cons k v) e))

(define (env-extend* kl vl e)
  (append (zip kl vl) e))

;; The compiler stage is based loosely on Abdulaziz Ghuloum's work
(define back:emit-expr
  (case-lambda
    [(expr)       (back:emit-expr expr '() back:compile)]
    [(expr env)   (back-emit-expr expr env back:compile)]
    [(expr env k)
     (match expr
       [`(lambda [,return-type -> ,formal-types ...] (,formals ...) ,body-expr)
        (back:emit-lambda return-type formals formal-types body-expr env k)]
       [(? symbol?)
        (k expr)]
       [E (error 'back:emit-expr "Unhandled expression type" E)])]))

(define (back:opengl:convert-name x)
  (pregexp-replace* "-" (symbol->string x) "_"))

(define (back:opengl:convert-type x)
  (match x
    [`[,return -> ,types ...] (error 'back:opengl:convert-type "opengl can't deal with function pointers")]
    [`[,type : ,count] (symbol->string type)]
    [E (error 'back:opengl:convert-type "unhandled type" E)]))

(define (back:opengl:gen-signature formals formal-types)
  (if (null? formals) "void"
      (string-interleave ", " (map (lambda (k t) (format "~a ~a" t k))
                                   (map back:opengl:convert-name formals)
                                   (map back:opengl:convert-type formal-types)))))
         

(define (back:emit-lambda return-type formals formal-types body-expr env k)
  (let ([new-env (env-extend* formals formal-types env)]
        [signature (gen-signature formals formal-types)])


  
  (k (back:emit-expr body-expr env (lambda (e)
                                     `(
         
