# Compilation-unit grammar (this slice)

Syntactic grammar recognized by [`Lovelace.Compiler.Parser`](parser.md) for one compilation unit (one `.love` file). Not a full Lovelace language grammar. Productions are **non-left-recursive** (LL(k) / recursive descent).

Lexical tokens come from [token-grammar.md](token-grammar.md). Whitespace between tokens is ignored by the tokenizer and does not appear in the token stream.

```ebnf
compilation_unit     = program_unit | module_unit ;
program_unit         = program_header , "begin" , "end" , "." ;
program_header       = "program" , identifier , ";" ;
module_unit          = module_header , "end" , "." ;
module_header        = "module" , qualified_identifier , ";" ;
qualified_identifier = identifier , { "." , identifier } ;
```

| Terminal | Token |
| --- | --- |
| `"program"` | keyword `program` |
| `"module"` | keyword `module` |
| `"begin"` | keyword `begin` |
| `"end"` | keyword `end` |
| `identifier` | identifier (including `@foo`, Unicode names) |
| `";"` | punctuation semicolon |
| `"."` | punctuation full stop (name separator or unit terminator) |

Examples (all valid when tokenized then parsed):

| Source | Notes |
| --- | --- |
| `program Hello; begin end.` | Canonical program |
| `program IDENTIFIER;begin end.` | No space after `;` |
| `    program   X ; begin end .  ` | Arbitrary spaces |
| `module Empty; end.` | Canonical empty module |
| `module Foo.Bar; end.` | Dotted module name |
| `module Foo.Bar;end.` | No space after `;` |

Not accepted in this slice: `end;` after a program `end`, `module …; begin end.` (modules have no `begin`), wrong keyword order, missing final `.`, trailing tokens after `.`, `Program` / `Module` as the first keyword (identifiers, not keywords), trailing `.` in a qualified name (`module Foo.;`).

The `.love` basename (excluding the extension) must equal the program or module name, including dots for modules (`Foo.Bar.love` ↔ `module Foo.Bar;`). See [cli.md](cli.md) and [`LV00009`](diagnostics.md).
