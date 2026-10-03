# Compilation-unit grammar (this slice)

Syntactic grammar recognized by [`Lovelace.Compiler.Parser`](parser.md) for one compilation unit (one `.love` file). Not a full Lovelace language grammar. Productions are **non-left-recursive** (LL(k) / recursive descent).

Lexical tokens come from [token-grammar.md](token-grammar.md). Whitespace between tokens is ignored by the tokenizer and does not appear in the token stream.

```ebnf
compilation_unit     = program_unit | module_unit ;
program_unit         = program_header , "begin" , "end" , "." ;
program_header       = "program" , identifier , ";" ;
module_unit          = module_header , { procedure_declaration } , "end" , "." ;
module_header        = "module" , qualified_identifier , ";" ;
qualified_identifier = identifier , { "." , identifier } ;

procedure_declaration = procedure_header , "begin" , "end" , ";" ;
procedure_header      = "procedure" , identifier , "(" , [ parameter_list ] , ")" , ";" ;
parameter_list        = parameter_group , { ";" , parameter_group } ;
parameter_group       = identifier , { "," , identifier } , ":" , type_name ;
type_name             = integer_type | float_type ;
integer_type          = [ "signed" | "unsigned" ] , "integer" , [ "<" , integer_size , ">" ] ;
integer_size          = "8" | "16" | "32" | "64" ;
float_type            = "float" , [ "<" , float_size , ">" ] ;
float_size            = "32" | "64" ;
```

Defaults: omitted signedness → signed; omitted integer size → 32; omitted float size → 32.

| Terminal | Token |
| --- | --- |
| `"program"` | keyword `program` |
| `"module"` | keyword `module` |
| `"procedure"` | keyword `procedure` |
| `"integer"` / `"float"` / `"signed"` / `"unsigned"` | matching keywords |
| `"begin"` | keyword `begin` |
| `"end"` | keyword `end` |
| `identifier` | identifier (including `@foo`, Unicode names) |
| `";"` / `"."` / `"("` / `")"` / `","` / `":"` / `"<"` / `">"` | punctuation |
| integer sizes in types | `Integer_Literal` tokens `8` / `16` / `32` / `64` |

Examples (all valid when tokenized then parsed):

| Source | Notes |
| --- | --- |
| `program Hello; begin end.` | Canonical program |
| `program IDENTIFIER;begin end.` | No space after `;` |
| `    program   X ; begin end .  ` | Arbitrary spaces |
| `module Empty; end.` | Canonical empty module |
| `module Foo.Bar; end.` | Dotted module name |
| `module MyModule; procedure Whatever(x : integer; y, z : float<32>); begin end; end.` | Module procedure with Ada-style params |

Not accepted in this slice: `end;` after a program `end`, `module …; begin end.` (modules have no unit-level `begin`), procedures inside `program` units, `float<16>` / `integer<128>`, wrong keyword order, missing final `.`, trailing tokens after `.`, `Program` / `Module` as the first keyword (identifiers, not keywords), trailing `.` in a qualified name (`module Foo.;`), duplicate parameter or procedure names ([`LV00011`](diagnostics.md)).

The `.love` basename (excluding the extension) must equal the program or module name, including dots for modules (`Foo.Bar.love` ↔ `module Foo.Bar;`). See [cli.md](cli.md) and [`LV00009`](diagnostics.md).
