# Compiler parser

`Lovelace.Compiler.Parser` turns a successful tokenizer `Token_Sequence` into a frontend AST module. It lives in crate `lovelace_compiler`. The parser is **recursive descent** (LL(k)): it consumes **one token at a time** and mirrors a non-left-recursive grammar. See also [compilation-unit-grammar.md](compilation-unit-grammar.md) and the Cursor rule `parser-recursive-descent`.

This slice accepts:

```text
program IDENTIFIER; begin end.
module QUALIFIED_NAME; { procedure …; begin end; } end.
```

Procedures appear only in `module` units (not `program`). Parameter lists are Ada-style (commas within a typed group; semicolons between groups). Lowering AST to LIR is documented in [ir-generator.md](ir-generator.md). Frontend AST and types remain distinct from LIR packages. The CLI wires Tokenize → Parse → Generate → backends; see [cli.md](cli.md).

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). Lexical tokens come from [tokenizer.md](tokenizer.md). Source spans and filenames: [source-locations.md](source-locations.md).

## Pipeline

```text
UTF-8 .love  →  Tokenize  →  Token_Sequence  →  Parse  →  Ast.Module  →  Generate  →  LIR
```

Callers tokenize first. `Parse` does not call `Tokenize`. Callers that need LIR call `Ir_Generator.Generate` after a successful parse.

## API

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Types` | Frontend `Type_Expression` (`Unit`, `Integer`, `Float`) |
| `Lovelace.Compiler.Ast` | Module, `Unit_Kind`, subroutine, parameters, `Full_Name`, flags, empty body |
| `Lovelace.Compiler.Parser` | `Parse`, `Parse_Result`, `Parser_Error` |
| `Lovelace.Compiler.Ir_Generator` | AST → LIR (see [ir-generator.md](ir-generator.md)) |

```ada
function Parse
  (Source_Text : String;
   Token_List  : Tokens.Token_Sequence) return Parse_Result;
```

`Parse_Result` is a module **or** errors, not both:

| `Ok` | Payload |
| --- | --- |
| `True` | `The_Module` — one compilation-unit AST |
| `False` | `Errors` — typically one located error (stop at first) |

Handle both discriminants. Do not read `The_Module` when `Ok` is `False`.

## Grammar (this slice)

See [compilation-unit-grammar.md](compilation-unit-grammar.md) for the full EBNF. Summary:

- Programs: `program` name `;` `begin` `end` `.` (no procedures).
- Modules: `module` qualified name `;` zero or more procedure declarations, then `end` `.`.
- Procedure: `procedure` name `(` [parameter list] `)` `;` `begin` `end` `;` — **no** `;` after `begin`.
- Types: `integer` / `signed integer` / `unsigned integer` with optional `<8|16|32|64>`; `float` with optional `<32|64>`.

Keywords are case-sensitive. The unit terminator after a unit-level `end` is only `.` (`Full_Stop`). Procedure bodies end with `end;`. Modules have **no** unit-level `begin`. Extra tokens after a complete unit are `Unexpected_Trailing`.

## AST shape

**Program** (`Unit_Kind = Program_Unit`):

- A module named `IDENTIFIER`
- One subroutine with the same name
- Empty body; return type **unit**; no parameters
- Flags: both `Export_Flag` and `Entrypoint_Flag`

**Module** (`Unit_Kind = Module_Unit`):

- A module named the qualified identifier (UTF-8 with `.` separators, e.g. `Foo.Bar`)
- Zero or more procedures (flags `0` — not exported / not entrypoint yet)
- Each procedure has unqualified `Name`, `Full_Name` = `ModuleName.ProcedureName`, ordered parameters, Unit return, empty body
- `Name_Span` on the module covers the whole qualified name

### Name rules

- Parameter names unique within a procedure
- Parameter name ≠ module name; ≠ any procedure name in the module
- Procedure name ≠ module name; procedure names unique in the module
- Violations → `Name_Clash` ([`LV00011`](diagnostics.md))

Spans cover names and the whole unit (first token through the final `.`). Optional filenames come from tokenization ([source-locations.md](source-locations.md)).

## Errors

| Code | Meaning |
| --- | --- |
| `Internal_Error` | Compiler bug (listed first) |
| `Unexpected_End_Of_Input` | A token was required but the cursor was at end |
| `Unexpected_Token` | Wrong kind/subtype at the cursor (including bad type sizes such as `float<16>`) |
| `Unexpected_Trailing` | Tokens remain after a complete unit |
| `Name_Clash` | Duplicate or conflicting procedure/parameter name |

Empty input / empty token list reports `Unexpected_End_Of_Input` at a synthetic span `(1,1,1)` when nothing was consumed.
