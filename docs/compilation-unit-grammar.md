# Compilation-unit grammar (this slice)

Syntactic grammar recognized by [`Lovelace.Compiler.Parser`](parser.md) for one compilation unit (one `.love` file). Not a full Lovelace language grammar. Productions are **non-left-recursive** (LL(k) / recursive descent).

Lexical tokens come from [token-grammar.md](token-grammar.md). Whitespace between tokens is ignored by the tokenizer and does not appear in the token stream. Flavor directives: [directives.md](directives.md).

```ebnf
compilation_unit     = { using_declaration } , [ version_attribute ] , ( program_unit | module_unit ) ;
version_attribute    = "@version" , "(" , string_literal , ")" ;
using_declaration    = "using" , qualified_identifier , ";" ;
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
native_clause         = "@native" , "(" , string_literal , "," , string_literal , ")"
                      | "@intrinsic" ;
block                 = { using_declaration } , [ declare_part ] , "begin" , { statement } , "end" ;
declare_part          = "declare" , variable_declaration , { variable_declaration } ;
variable_declaration  = identifier , { "," , identifier } , ":" , type_name , ";" ;
statement             = call_statement | assignment_statement | block_statement ;
block_statement       = block , ";" ;
assignment_statement  = identifier , ":=" , expression , ";" ;
call_statement        = callee_name , "(" , [ argument_list ] , ")" , ";" ;
callee_name           = identifier , "." , identifier , { "." , identifier } ;
argument_list         = argument , { "," , argument } ;
argument              = expression ;
expression            = integer_literal | "true" | "false" | identifier ;
parameter_list        = parameter_group , { ";" , parameter_group } ;
parameter_group       = identifier , { "," , identifier } , ":" , type_name ;
type_name             = integer_type | float_type | boolean_type ;
integer_type          = [ "signed" | "unsigned" ] , "integer" , [ "<" , integer_size , ">" ] ;
integer_size          = "8" | "16" | "32" | "64" ;
float_type            = "float" , [ "<" , float_size , ">" ] ;
float_size            = "32" | "64" ;
boolean_type          = "boolean" ;

flavor_conditional    = "#if" , flavor_condition , { module_declaration } ,
                        { "#elsif" , flavor_condition , { module_declaration } } ,
                        [ "#else" , { module_declaration } ] ,
                        "#end" ;
flavor_condition      = "flavor" , "=" , string_literal ;
```

`string_literal` content for `@version` must be a module version, `MAJOR.MINOR.BUILD[-preview-name[.preview-number]]`: numeric parts are non-negative integers without leading zeroes, and the preview name is `[A-Za-z0-9-]+` ([`LV00034`](diagnostics.md) otherwise). The attribute is optional and, when present, comes after the leading usings and before `program` / `module`. Version priority: `@version`, then the library's `.loveversion`, then `lovelace compile --module-version`, then `0.0.1` ([cli.md](cli.md)).

Defaults: omitted signedness → signed; omitted integer size → 32; omitted float size → 32.

`string_literal` content for a flavor condition must be exactly `wasi`, `native`, or `web` ([`LV00012`](diagnostics.md) otherwise). Active flavor comes from `lovelace compile --flavor` (default `wasi`). Inactive arms are parsed for syntax but omitted from the AST.

| Terminal | Token |
| --- | --- |
| `"@version"` | identifier token with lexeme `@version` |
| `"program"` | keyword `program` |
| `"module"` | keyword `module` |
| `"using"` | keyword `using` |
| `"export"` | keyword `export` |
| `"procedure"` | keyword `procedure` |
| `"integer"` / `"float"` / `"signed"` / `"unsigned"` / `"boolean"` | matching keywords |
| `"true"` / `"false"` | boolean literal keywords (expressions / call arguments) |
| `"begin"` | keyword `begin` |
| `"end"` | keyword `end` |
| `"declare"` | keyword `declare` |
| `"#if"` / `"#elsif"` / `"#else"` / `"#end"` | directive tokens |
| `identifier` | identifier (including `@foo`, Unicode names; `flavor` in conditions; also `import` / `native`) |
| `string_literal` | double-quoted string (no escapes in this slice) |
| `";"` / `"."` / `"("` / `")"` / `","` / `":"` / `":="` / `"<"` / `">"` / `"="` | punctuation |
| integer sizes in types | `Integer_Literal` tokens `8` / `16` / `32` / `64` |

Examples (all valid when tokenized then parsed):

| Source | Notes |
| --- | --- |
| `program Hello; begin end.` | Canonical program |
| `program P; declare X : integer; begin end.` | Optional non-empty `declare` before `begin` |
| `program P; begin declare Y : boolean; begin end; end.` | Nested `block_statement` (`end;`) |
| `using augusta.std.io; program Hello; begin end.` | Leading using before program |
| `program P; begin using Lib; declare X : integer; begin X := 1; end; end.` | Block-scoped using then declare |
| `program P; declare X : integer; begin X := 7; end.` | Assignment |
| `program IDENTIFIER;begin end.` | No space after `;` |
| `    program   X ; begin end .  ` | Arbitrary spaces |
| `module Empty; end.` | Canonical empty module |
| `using Lib.A; module Host; end.` | Leading using before module |
| `module Foo.Bar; end.` | Dotted module name |
| `module MyModule; procedure Whatever(x : integer; y, z : float<32>); begin end; end.` | Module procedure with Ada-style params |
| `module Lib; export procedure Print(Value : integer); begin end; end.` | Exported module procedure (`Export_Flag`) |
| `module Lib; export @intrinsic procedure print(value : integer); end.` | Intrinsic (`Intrinsic_Flag`; no `begin`…`end`; IR matches closed table) |
| `module Lib; export @native("libx", "print_fn") procedure print(value : integer); end.` | Native FFI (`Native_Flag` + library/function; no `begin`…`end`) |
| `module Calls; procedure Sink(V : integer); begin end; procedure Run(); begin Calls.Sink(42); end; end.` | Qualified call with integer literal arg |
| `module Bools; procedure Sink(F : boolean); begin end; procedure Run(); begin Bools.Sink(true); end; end.` | `boolean` param + `true`/`false` args |
| `module FlavorSelect; #if flavor = "wasi" procedure WasiOnly(); begin end; #end end.` | Flavor selection (see [samples](samples.md)) |

Usings may be **file-leading** (before `program` / `module`) **or** at the start of a **block** (before optional `declare` / `begin`). Duplicate using names and self-using (using name equals the unit name), or a nested using that shadows an enclosing using, are `Name_Clash` ([`LV00011`](diagnostics.md)). Sibling nested blocks may each `using M;`. `using … as …` is reserved and not parsed. Lexeme `import` is not a keyword — writing `import M;` fails as `Unexpected_Token`.

Not accepted in this slice: `using` after `declare` / after `begin` (wrong preamble order), `end;` after a program `end`, `module …; begin end.` (modules have no unit-level `begin`), procedures inside `program` units, `#if` in `program` units or inside procedure bodies, empty `declare` (`declare begin`), shadowing / duplicate locals / locals that reuse unit entity or parameter names ([`LV00011`](diagnostics.md)), bare `native(…)` headers (`native` is an ordinary identifier), `@intrinsic`/`@native` together with a `begin`…`end` body, unqualified call targets (`Sink(42);` — need `MODULE.SUBROUTINE`), operators / general expressions beyond literal / identifier, `float<16>` / `integer<128>` / `boolean<…>`, wrong keyword order, missing final `.`, trailing tokens after `.`, `Program` / `Module` as the unit keyword (identifiers, not keywords), trailing `.` in a qualified name (`module Foo.;`), duplicate parameter names, or duplicate procedure **signatures** (same name + same ordered parameter types; return type ignored) among **surviving** declarations ([`LV00011`](diagnostics.md)). Same procedure name with different parameter types is allowed (overload). Call-target / overload resolve, definite assignment, and typecheck run in **semantics** after parse ([`diagnostics.md`](diagnostics.md)). `@intrinsic` signature matching against the closed table is an IR concern ([`LV00025`](diagnostics.md)).

**Scopes:** each block’s usings and `declare` push names for that block only (visible inward, not outward). Nested blocks must not shadow enclosing usings/locals/parameters or clash with the unit name / subroutine names in the same unit. Sibling nested blocks may reuse the same local or using name. Semantic resolve / DA / types / unused: [semantics.md](semantics.md).

The `.love` basename (excluding the extension) must equal the program or module name, including dots for modules (`Foo.Bar.love` ↔ `module Foo.Bar;`). See [cli.md](cli.md) and [`LV00009`](diagnostics.md).
