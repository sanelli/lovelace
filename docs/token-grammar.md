# Token grammar (this slice)

Lexical grammar recognized by [`Lovelace.Compiler.Tokenizer`](tokenizer.md). Not a full Lovelace language grammar. The compilation-unit syntax for this slice is in [compilation-unit-grammar.md](compilation-unit-grammar.md). Directives: [directives.md](directives.md).

```ebnf
tokens        = { whitespace | comment | token | error } ;
token         = keyword | identifier | punctuation | integer_literal
              | float_literal | directive | string_literal ;
keyword       = "program" | "module" | "begin" | "end" | "export" | "import" | "native"
              | "procedure" | "integer" | "float" | "signed" | "unsigned"
              | "boolean" | "true" | "false" ;
              (* case-sensitive *)
punctuation   = ";" | "." | "(" | ")" | "," | ":" | "<" | ">" | "=" ;
directive     = "#if" | "#elsif" | "#else" | "#end" ;
string_literal = '"' , { string_character } , '"' ;
(* no escape sequences in this slice; Lexeme includes both quotes *)

identifier    = [ "@" ] identifier_first { identifier_continue } ;
(* "@" only after start, whitespace, punctuation, directive, or string *)

integer_literal = [ "+" | "-" ] , prefixed_or_decimal , [ signedness ] , [ size ] ;
prefixed_or_decimal = "0b" , binary_digits | "0B" , binary_digits
                    | "0o" , octal_digits | "0O" , octal_digits
                    | "0x" , hex_digits | "0X" , hex_digits
                    | digits ;
binary_digits   = "0" | "1" , { "0" | "1" } ;
octal_digits    = octal_digit , { octal_digit } ;
hex_digits      = hex_or_digit , { hex_or_digit } ;
signedness      = "s" | "u" ;
size            = "8" | "16" | "32" | "64" ;

float_literal   = [ "+" | "-" ] ,
                  ( digits , "." , [ fraction ] , [ exponent ] , [ float_width ]
                  | digits , exponent , [ float_width ]
                  | digits , float_width ) ;
fraction        = digits ;
exponent        = ( "e" | "E" ) , [ "+" | "-" ] , digits ;
float_width     = "f32" | "F32" | "f64" | "F64" ;

whitespace    = whitespace_scalar , { whitespace_scalar } ;
(* ignored: not emitted, not part of the adjacent tokens *)

comment       = "{" , { comment_character } , "}" ;
(* ignored like whitespace; not emitted. No nesting: `{` inside a comment is an error.
   `{` / `}` inside a string_literal are not comment delimiters. *)

error         = unrecognized_symbol | invalid_utf_8 | unterminated_string_literal
              | unterminated_comment | nested_comment | stray_comment_closer ;
```

`identifier_first` / `identifier_continue` are Unicode-scalar predicates documented in [tokenizer.md](tokenizer.md). `_` is allowed; ASCII digits may continue an identifier but must not start one (except after `@`).

Scan order (longest match): float → integer → directive → string → identifier → punctuation. Exact directive lexemes (`#if`, …) still match; old Ada-style `#BASE#` integer spellings are not tokens (ordinary tokenization failure).

Float forms are tried before integer forms so `1.0`, `1e3`, and `7f32` are each one `Float_Literal`. Hex prefixes win over float suffixes (`0xf` / `0xF32` are integers).

Examples:

| Source | Tokens (on success) |
| --- | --- |
| `program begin end.` | `program` `begin` `end` `.` |
| `module Foo.Bar; end.` | `module` `Foo` `.` `Bar` `;` `end` `.` |
| `procedure P(x : integer);` | `procedure` `P` `(` `x` `:` `integer` `)` `;` |
| `export procedure Print(Value : integer);` | `export` `procedure` `Print` `(` `Value` `:` `integer` `)` `;` |
| `export @intrinsic procedure print(value : integer);` | `export` `@intrinsic` `procedure` … |
| `export @native("libx", "print_fn") procedure print(value : integer);` | `export` `@native` `(` `"libx"` `,` `"print_fn"` `)` `procedure` … |
| `import Foo.Bar;` | `import` `Foo` `.` `Bar` `;` |
| `42` `-3u16` `0xFFs32` `0b1010` `0o755` | integer literals |
| `3.14` `7.` `1e3` `7f32` `2.3f64` | float literals |
| `boolean` `true` `false` | keywords |
| `#if` `#elsif` `#else` `#end` | directive tokens |
| `"wasi"` | string literal (lexeme includes quotes) |
| `flavor = "web"` | identifier `flavor`, `=`, string `"web"` |
| `end;` | `end` `;` |
| `Program` | identifier `Program` |
| `programmer` | identifier `programmer` |
| `modulex` | identifier `modulex` |
| `@foo` | identifier `@foo` |
