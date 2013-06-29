;; Compiler back end.

;; We deal with a language which is already typed and reduced into a form that's easily
;; compilable.
;; Given the impedance mismatch between Scheme's full number stack and
;; the underlying layer's meagre intrinsics, we will, for the moment, go with
;; meagre types.  Yeah, it sucks.

;; type          := atomic-type | lambda-type
;; scalar-type   := intrinsic-type | void | any
;; atomic-type   := [scalar-type . count]
;; lambda-type   := [(type ...) -> type]
;;
;; expr          := const-expr | var-expr | lambda-expr | sel-expr |
;;                  let-expr | seq-expr | app-expr | tail-expr | return-expr
;; const-expr    := literal-expr | var-expr
;; literal-expr  := value
;; var-expr      := symbol
;; lambda-expr   := (lambda lambda-type (var-expr ...) expr)
;; sel-expr      := (select type expr const-expr const-expr)
;; let-expr      := (let (var-expr type expr) expr)
;; seq-expr      := (begin expr expr)
;; app-expr      := (expr expr ...)
;; tail-expr     := (tail expr expr ...)
;; return-expr   := (return expr)
(import (core) (pregexp) (match))

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

(define (back:compile str)
  str)

(define var-expr? symbol?)
(define (literal-expr? x)
  (or (number? x) (boolean? x) (char? x) (string? x)))
(define (const-expr? x)
  (or (var-expr? x) (literal-expr? x)))

;; The compiler stage is based loosely on Abdulaziz Ghuloum's work
(define back:emit-expr
  (case-lambda
    [(expr)                  (back:emit-expr expr '(void . 0))]
    [(expr target-type)      (back:emit-expr expr target-type '())]
    [(expr target-type env)  (back:emit-expr expr target-type env back:compile)]
    [(expr target-type env k)
     (match expr
       [`(lambda [(,formal-types ...) -> ,return-type] (,formals ...) ,body-expr)
        (back:emit-lambda return-type formals formal-types body-expr target-type env k)]
       [`(select ,type ,test-expr ,consequence ,alternate)
        (back:emit-select-expr type test-expr consequence alternate target-type env k)]
       [(? var-expr?)
        (back:emit-var expr target-type env k)]
       [(? literal-expr?)
        (back:emit-literal expr target-type env k)]
       [E (error 'back:emit-expr "Unhandled expression type" E)])]))

(define (back:opengl:convert-name x)
  (pregexp-replace* "-" (symbol->string x) "_"))

(define (back:opengl:convert-type-representation x)
  (match x
    [`[,types ... -> ,return] (error 'back:opengl:convert-type-representation "opengl can't deal with function pointers")]
    [`[,type . ,count] (symbol->string type)]
    [E (error 'back:opengl:convert-type-representation "unhandled type" E)]))

(define (back:opengl:gen-signature formals formal-types)
  (if (null? formals) "void"
      (string-interleave ", " (map (lambda (k t) (format "~a ~a" t k))
                                   (map back:opengl:convert-name formals)
                                   (map back:opengl:convert-type-representation formal-types)))))

;; Emit a variable expression
(define (back:emit-var expr target-type env k)
  (let ([env-type (assoc expr env)])
    (if (null? env-type)
        (error 'back:emit-var "variable not defined in compile-time env" expr)
        (back:opengl:emit-type-conversion (cdr env-type)
                                          target-type
                                          (back:opengl:convert-name expr) k))))

;; Emit a literal expression
(define (back:emit-literal expr target-type env k)
  (let ([intrinsic-type (cond [(integer? expr) '[int . 1]]
                              [(number? expr)  '[float . 1]]
                              [(boolean? expr) '[bool . 1]]
                              [(char? expr)    '[uint . 1]]
                              [else (error 'back:emit-literal "don't know how to handle this type yet" expr)])])
    (back:opengl:emit-type-conversion intrinsic-type target-type expr k)))

;; Emit a type conversion
(define (back:opengl:emit-type-conversion src-type dest-type expr k)
  ;; Simplest thing that could possibly work for the moment
  (if (and (eqv? (car dest-type) (car src-type))
           (= (cdr dest-type) (cdr src-type)))
      (k (format "~a" expr))
      (k (format "~a(~a)" (car dest-type) expr))))

;; Emitting a lambda expression
(define (back:emit-lambda return-type formals formal-types body-expr target-type env k)
  (let ([new-env (env-extend* formals formal-types env)]
        [signature (back:opengl:gen-signature formals formal-types)])
    (k (back:emit-expr body-expr new-env
                       (lambda (e) (format "(~a) { ~a }" signature e))))))


(import (test test-lite))

(test-begin "low level expression handling")

(test-eval!
 (define env
   '((a . [float . 1])
     (b . [vec4 . 2])
     (abc-def . [int . 1]))))

(test-eval!
 (define (identity x) x))

(test-equal (back:emit-expr 'a '[float . 1] env identity) "a")
(test-equal (back:emit-expr 'a '[int . 1] env identity) "int(a)")
(test-equal (back:emit-expr 'abc-def '[int . 1] env identity) "abc_def")
(test-equal (back:emit-expr '1 '[int . 1] env identity) "1")
(test-equal (back:emit-expr '1 '[float . 1] env identity) "float(1)")
(test-equal (back:emit-expr '1 '[mat3 . 1] env identity) "mat3(1)")

#;(test-equal (back:emit-expr '(lambda [([int . 1] [float . 1]) -> [void . 0]] (a b) a)) env identity
            "(int a, float b) { a; }")

(test-end)
