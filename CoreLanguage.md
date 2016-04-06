# Combo Lisp: Core Language #

## Preliminaries ##

  * Unless otherwise specified, a sequence of entities may be empty, and the entities themselves are separated by whitespace.
  * Whitespace is one or more spaces, tabs, and/or newlines. Unless otherwise specified, any amount of whitespace may occur between any two consecutive entities.
  * A name is an identifier or a scalar.
    * An identifier is a nonempty sequences of digits, letters, and underscores, not beginning with a digit, containing no whitespace.
    * A scalar is dollar sign (`$`) followed by an identifier, with no intervening whitespace.
  * Matched parentheses (`(` and `)`) may be placed around any entity.

## Core Syntax ##

A program is a sequence of expressions.
  * An expression is a name, a literal, or a function application.
    * A literal is a Boolean literal, number literal, character literal, or nil.
      * A Boolean literal is `true` or `false`.
      * A number literal is a nonempty sequence of digits (`0-9`), optionally preceded by a minus sign (`-`), optionally containing exactly one period (`.`) in some position other than the last, containing no whitespace.
        * _Examples:_ `-3.14`, `2003.0`, `.5`, `42`, `109`, `-00`
      * A character literal is a normal character literal or an escaped character literal.
        * A normal character literal is single quote (`'`), followed by a single character other than a single quote or a hash (`#`), followed by a single quote.
        * An escaped character literal is a single quote, followed by a backslash (`\`), followed by a `t` (tab), `n` (newline), `#`, `\`,  or single quote.
    * _Examples:_ `'a'`, `'\n'`, `'\'`, `'\''`
      * Nil is an empty pair of brackets (`[]`).
      * A function application is a left paren (`(`), followed by an identifier, followed by a nonempty sequence of expressions, followed by a right paren (`)`).
        * _Examples:_ `(foo 1 2 'x' (bar $x))`, `(bla ())`, `(baz 3.4 [] 1 2 3 [])`

## Syntactic Sugar ##

Every combo program may be expressed using nothing but the core syntax. For convenience however, the following syntactic sugar is provided. Every sugared program corresponds to exactly one unsugared program. For historical reasons, sugared expressions are known as m-expressions, while unsugared programs are known as s-expressions.

### Operators ###

A number of operators (primaily infix, but some prefix as well) are provided; each is equivalent to some function application expression. The operators are listed in ascending order of precedence. The arity of an expression may be the same for both forms or may be different, as indicated in the table. Infix operations of equal precedence are left-associative, except for `tuple` (`,`) and `cons` (`:`), which are right-associative.

| _Infix_ | _Arity_ | _Example M-Expression_ | _Equivalent Function Application S-Expression_ |
|:--------|:--------|:-----------------------|:-----------------------------------------------|
| `[,]`   | `variadic` | `[a b c,[],foo (foo bar)]` | `(list (a b c) nil (foo (foo bar)))`           |
| `[..]`  | `2`     | `[foo bar..42]`        | `(range (foo bar) 42)`                         |
| `[...]` | `2`     | `[1...10]`             | `(xrange 1 10)`                                |
| `(,)`   | `variadic, 2` | `(a,b,c,d e f,[])`     | `(tuple a b c (d e f) nil)`                    |
| `=` 	   |  `variadic, 3` | `foo $x $y = bla bla`  | `(def foo (list $x $y) (bla bla))`             |
| `\`	    | `1`     | `\foo bar baz`         | `(lambda (foo bar baz))`                       |
| `<-`	   | `1`     | `<- x y z`             | `(fact (x y z))`                               |
| `^` 	   | `2`     | `foo^3`                | `(decl foo 3)`                                 |
| `->`    | `2`     | `foo bar -> baz bap`   | `(arrow (foo bar) (baz bap))`                  |
| `|``|`   | `variadic` | `a |``| b |``| c`      | `(or a b c)`                                   |
| `&&`	   | `variadic` | `a && b && c`          | `(and a b c)`                                  |
| `:` 	   | `2`     | `4:[3,2,1]`            | `(cons 4 (list 3 2 1))`                        |
| `== !=` | `2`     | `a==b && c!=d`         | `(and (equal a b) (not_equal c d))`            |
| `<= >= < >` | `2`     | `a<=b |``| x+y>d |``| q>=r` | `(or (less_equal a b) (greater (plus x y) d) (greater_equal q r))` |
| `+ -`   | `variadic` | `a+b-c`                | `(minus (plus a b) c)`                         |
| `~`     | `variadic` | `a~b~c`                | `(concat a b c)`                               |
| `*` 	   | `variadic` | `a*b+c*d`              | `(plus (times a b) (times c d))`               |
| `/`     | `2`     | `a+b/c*d`              | `(plus a (times (div b c) d))`                 |
| `! -`   | `1`     | `!a |``| -b<c`         | `(or (not a) (less (negative b) c))`           |

Operator expressions may be nested without parentheses, as shown in many of the examples - ambiguity is resolved according to precedence, with function application having the lowest order of precedence, e.g `(f a+b)` is equivalent to `(f (plus a b))`. However, all top-level expressions must be enclosed in parentheses, even operator expressions.

## Application ##

Function applications in the core language consist of an identifier followed by a sequence of expressions. For convenience, an m-expression consisting of non-empty sequences of expressions, even when the initial expression is not an identifier. In such cases, the equivalent s-expression is a function application expression consisting of the identifier `apply`, followed by the initial expression, followed by the remaining expressions, if any, grouped as a list (a function-application expression with the identifier `list`). For example, `((if foo bar baz) la di da)` is equivalent to `(apply (if foo bar baz) (list la di da))`.

### String literals ###

A string in double-quotes (`"`) is sugar for the equivalent list of characters.  The same escape-sequences recognized in character literals are recognized in string literals, with the exception of the escaped single-quote, and the addition of the escaped double-quote.
So for example `"foobar"` is equivalent to `['f', 'o', 'o', 'b', 'a', 'r']`, and `"b'la\"bla"` is equivalent to `['b' '\'', 'l', 'a', '"', 'b', 'l', 'a']`, etc.

### Comments ###

Comments begin with a `#` and run until a newline is reached, with the exception of escaped `#`s within character and string literals, which do not begin comments. Whenever a comment appears it is equivalent to the empty string.

## Core Semantics ##

Combo semantics describe how expressions are _evaluated_ to produce new expressions (results of computations). Individual functions

### Literals ###

Literal expressions evaluate to themselves.



Nested expressions naturally correspond to a treelike structure. For example, in `(plus (times a b) c)`, `plus` is the root node and has two children, the subtree `(times a b)` and the leaf `c`. Combo Lisp does no