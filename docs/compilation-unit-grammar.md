# Compilation-unit grammar (this slice)

Syntactic grammar recognized by [`Lovelace.Compiler.Parser`](parser.md) for one compilation unit (one `.love` file). Not a full Lovelace language grammar. Productions are **non-left-recursive** (LL(k) / recursive descent).

Lexical tokens come from [token-grammar.md](token-grammar.md). Whitespace between tokens is ignored by the tokenizer and does not appear in the token stream. Flavor directives: [directives.md](directives.md).

```ebnf
compilation_unit     = { import_declaration } , ( program_unit | module_unit ) ;
import_declaration   = "import" , qualified_identifier , ";" ;
program_unit         = program_header , block , "." ;
program_header       = "program" , identifier , ";" ;
module_unit          = module_header , { module_declaration } , "end" , "." ;
module_header        = "module" , qualified_identifier , ";" ;
module_declaration   = procedure_declaration | flavor_conditional ;
qualified_identifier = identifier , { "." , identifier } ;

procedure_declaration = ordinary_procedure | native_procedure ;
ordinary_procedure    = [ "export" ] , "procedure" , identifier ,
                        "(" , [ parameter_list ] , ")" , ";" , block , ";" ;
native_procedure      = [ "export" ] , native_clause , "procedure" , identifier ,
                        "(" , [ parameter_list ] , ")" , ";" ;
native_clause         = "native" , "(" , string_literal , "," , string_literal , ")" ;
block                 = "begin" , { statement } , "end" ;
statement             = call_statement ;
call_statement        = callee_name , "(" , [ argument_list ] , ")" , ";" ;
callee_name           = identifier , "." , identifier , { "." , identifier } ;
argument_list         = integer_literal , { "," , integer_literal } ;
parameter_list        = parameter_group , { ";" , parameter_group } ;
parameter_group       = identifier , { "," , identifier } , ":" , type_name ;
type_name             = integer_type | float_type ;
integer_type          = [ "signed" | "unsigned" ] , "integer" , [ "<" , integer_size , ">" ] ;
integer_size          = "8" | "16" | "32" | "64" ;
float_type            = "float" , [ "<" , float_size , ">" ] ;
float_size            = "32" | "64" ;

flavor_conditional    = "#if" , flavor_condition , { module_declaration } ,
                        { "#elsif" , flavor_condition , { module_declaration } } ,
                        [ "#else" , { module_declaration } ] ,
                        "#end" ;
flavor_condition      = "flavor" , "=" , string_literal ;
```

Defaults: omitted signedness → signed; omitted integer size → 32; omitted float size → 32.

`string_literal` content for a flavor condition must be exactly `wasi`, `native`, or `web` ([`LV00012`](diagnostics.md) otherwise). Active flavor comes from `lovelace build --flavor` (default `wasi`). Inactive arms are parsed for syntax but omitted from the AST.

| Terminal | Token |
| --- | --- |
| `"program"` | keyword `program` |
| `"module"` | keyword `module` |
| `"import"` | keyword `import` |
| `"export"` | keyword `export` |
| `"native"` | keyword `native` |
| `"procedure"` | keyword `procedure` |
| `"integer"` / `"float"` / `"signed"` / `"unsigned"` | matching keywords |
| `"begin"` | keyword `begin` |
| `"end"` | keyword `end` |
| `"#if"` / `"#elsif"` / `"#else"` / `"#end"` | directive tokens |
| `identifier` | identifier (including `@foo`, Unicode names; `flavor` in conditions) |
| `string_literal` | double-quoted string (no escapes in this slice) |
| `";"` / `"."` / `"("` / `")"` / `","` / `":"` / `"<"` / `">"` / `"="` | punctuation |
| integer sizes in types | `Integer_Literal` tokens `8` / `16` / `32` / `64` |

Examples (all valid when tokenized then parsed):

| Source | Notes |
| --- | --- |
| `program Hello; begin end.` | Canonical program |
| `import augusta.std.io; program Hello; begin end.` | Leading import before program |
| `program IDENTIFIER;begin end.` | No space after `;` |
| `    program   X ; begin end .  ` | Arbitrary spaces |
| `module Empty; end.` | Canonical empty module |
| `import Lib.A; module Host; end.` | Leading import before module |
| `module Foo.Bar; end.` | Dotted module name |
| `module MyModule; procedure Whatever(x : integer; y, z : float<32>); begin end; end.` | Module procedure with Ada-style params |
| `module Lib; export procedure Print(Value : integer); begin end; end.` | Exported module procedure (`Export_Flag`) |
| `module Lib; export native("wasi", "native-print-integer") procedure print(value : integer); end.` | Native binding (`Native_Flag`; no `begin`…`end`) |
| `module Calls; procedure Sink(V : integer); begin end; procedure Run(); begin Calls.Sink(42); end; end.` | Qualified call with integer literal arg |
| `module FlavorSelect; #if flavor = "wasi" procedure WasiOnly(); begin end; #end end.` | Flavor selection (see [samples](samples.md)) |

Imports are **file-leading** only (before `program` / `module`). Duplicate import names and self-import (import name equals the unit name) are `Name_Clash` ([`LV00011`](diagnostics.md)). `import … as …` is reserved and not parsed.

Not accepted in this slice: `import` after `program`/`module`, inside procedure bodies, or inside `#if` arms; `end;` after a program `end`, `module …; begin end.` (modules have no unit-level `begin`), procedures inside `program` units, `#if` in `program` units or inside procedure bodies, `native(…)` together with a `begin`…`end` body, unqualified call targets (`Sink(42);` — need `MODULE.SUBROUTINE`), non-integer call arguments, `float<16>` / `integer<128>`, wrong keyword order, missing final `.`, trailing tokens after `.`, `Program` / `Module` as the unit keyword (identifiers, not keywords), trailing `.` in a qualified name (`module Foo.;`), duplicate parameter or procedure names among **surviving** declarations ([`LV00011`](diagnostics.md)). Cross-module call **resolution** is a later step; such calls may still parse. Native target/key checking against the closed WASI intrinsic set is an IR/backend concern (later steps).

The `.love` basename (excluding the extension) must equal the program or module name, including dots for modules (`Foo.Bar.love` ↔ `module Foo.Bar;`). See [cli.md](cli.md) and [`LV00009`](diagnostics.md).
