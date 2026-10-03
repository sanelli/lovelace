# Token grammar (this slice)

Lexical grammar recognized by [`Lovelace.Compiler.Tokenizer`](tokenizer.md). Not a full Lovelace language grammar. The compilation-unit syntax for this slice is in [compilation-unit-grammar.md](compilation-unit-grammar.md).

```ebnf
tokens        = { whitespace | token | error } ;
token         = keyword | identifier | punctuation | integer_literal | float_literal ;
keyword       = "program" | "module" | "begin" | "end"
              | "procedure" | "integer" | "float" | "signed" | "unsigned" ;
              (* case-sensitive *)
punctuation   = ";" | "." | "(" | ")" | "," | ":" | "<" | ">" ;
identifier    = [ "@" ] identifier_first { identifier_continue } ;
(* "@" only after start, whitespace, or punctuation; not after an identifier *)

integer_literal = [ "+" | "-" ] , [ "#" , base , "#" ] , digits , [ signedness ] , [ size ] ;
base            = "2" | "8" | "10" | "16" ;
signedness      = "s" | "u" ;
size            = "8" | "16" | "32" | "64" ;

float_literal   = [ "+" | "-" ] , digits , "." , [ fraction ] , [ exponent ] ;
fraction        = digits ;
exponent        = ( "e" | "E" ) , [ "+" | "-" ] , digits ;

whitespace    = whitespace_scalar , { whitespace_scalar } ;
(* ignored: not emitted, not part of the adjacent tokens *)

error         = unrecognized_symbol | invalid_utf_8 ;
```

`identifier_first` / `identifier_continue` are Unicode-scalar predicates documented in [tokenizer.md](tokenizer.md). `_` is allowed; ASCII digits may continue an identifier but must not start one (except after `@`).

Float forms are tried before integer forms so `1.0` is one `Float_Literal`, not `1` plus punctuation.

Examples:

| Source | Tokens (on success) |
| --- | --- |
| `program begin end.` | `program` `begin` `end` `.` |
| `module Foo.Bar; end.` | `module` `Foo` `.` `Bar` `;` `end` `.` |
| `procedure P(x : integer);` | `procedure` `P` `(` `x` `:` `integer` `)` `;` |
| `42` `-3u16` `16#FF#s32` | integer literals |
| `3.14` `7.` `1e-3` | float literals |
| `end;` | `end` `;` |
| `Program` | identifier `Program` |
| `programmer` | identifier `programmer` |
| `modulex` | identifier `modulex` |
| `@foo` | identifier `@foo` |
