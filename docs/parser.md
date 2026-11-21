# Compiler parser

`Lovelace.Compiler.Parser` turns a successful tokenizer `Token_Sequence` into a frontend AST module. It lives in crate `lovelace_compiler`. The parser is **recursive descent** (LL(k)): it consumes **one token at a time** and mirrors a non-left-recursive grammar. See also [compilation-unit-grammar.md](compilation-unit-grammar.md) and the Cursor rule `parser-recursive-descent`.

This slice accepts:

```text
{ using QUALIFIED_NAME; } program IDENTIFIER; block .
{ using QUALIFIED_NAME; } module QUALIFIED_NAME; { module_declaration } end.
```

Leading `using` declarations (if any) come **before** `program` / `module`. A `module_declaration` is either a `procedure` or a **flavor conditional** (`#if` … `#end`). Procedures appear only in `module` units (not `program`). Parameter lists are Ada-style (commas within a typed group; semicolons between groups). Flavor selection: [directives.md](directives.md). After parse, **semantics** (environment, definite assignment, types, call resolve, unused warnings) runs before IR; see [semantics.md](semantics.md), [diagnostics.md](diagnostics.md), and [ir-generator.md](ir-generator.md). Frontend AST and types remain distinct from LIR packages. The CLI wires Tokenize → Parse → Semantics → Generate → backends; see [cli.md](cli.md).

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). Lexical tokens come from [tokenizer.md](tokenizer.md). Source spans and filenames: [source-locations.md](source-locations.md).

## Pipeline

```text
UTF-8 .love  →  Tokenize  →  Token_Sequence  →  Parse (Active_Flavor)  →  Ast.Module
                                                                              ↓
                                                                         Semantics
                                                                              ↓
                                                                         Generate → LIR
```

Callers tokenize first. `Parse` does not call `Tokenize`. Callers that need LIR call semantics then `Ir_Generator.Generate` after a successful parse.

## API

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Flavor` | `Wasi` / `Native` / `Web`, `Default`, `Name`, `Try_Parse_Name` |
| `Lovelace.Compiler.Types` | Frontend `Type_Expression` (`Unit`, `Boolean`, `Integer`, `Float`) |
| `Lovelace.Compiler.Ast` | Module, `Unit_Kind`, usings, subroutine, parameters, `Full_Name`, flags, blocks / expressions |
| `Lovelace.Compiler.Parser` | `Parse`, `Parse_Result`, `Parser_Error` |
| `Lovelace.Compiler.Semantics` | Environment, DA, typecheck, call resolve, unused warnings (before IR); see [semantics.md](semantics.md) |
| `Lovelace.Compiler.Ir_Generator` | AST → LIR (see [ir-generator.md](ir-generator.md)) |

```ada
function Parse
  (Source_Text   : String;
   Token_List    : Tokens.Token_Sequence;
   Active_Flavor : Flavor.Flavor_Name := Flavor.Default) return Parse_Result;
```

`Active_Flavor` selects which arm of each `#if` / `#elsif` / `#else` chain survives into the AST. Default is `Wasi` (same as CLI `--flavor` default).

`Parse_Result` is a module **or** errors, not both:

| `Ok` | Payload |
| --- | --- |
| `True` | `The_Module` — one compilation-unit AST |
| `False` | `Errors` — typically one located error (stop at first) |

Handle both discriminants. Do not read `The_Module` when `Ok` is `False`.

## Grammar (this slice)

See [compilation-unit-grammar.md](compilation-unit-grammar.md) for the full EBNF. Summary:

- Leading usings: zero or more `using` qualified-name `;` before the unit keyword.
- Programs: `program` name `;` block `.` (no procedures, no `#if`).
- Modules: `module` qualified name `;` zero or more `module_declaration`s, then `end` `.`.
- **Block:** `{ using …; }` `[ declare … ] begin { statement } end`. Usings (if any) come before `declare` before `begin`. When `declare` is present, at least one variable declaration is required.
- Statements: qualified call, assignment (`id := expr;`), or nested `block` + `;` (nested terminator is `end;`).
- Expressions (this slice): integer literal | `true` | `false` | identifier. Call arguments are expressions.
- `module_declaration`: `procedure` (ordinary, `@intrinsic`, or `@native`) **or** flavor conditional (`#if flavor = "…" … `#end`).
- Flavor conditional: parse **all** arms; keep only the active arm’s declarations; discard the rest (no AST for inactive arms). Conditions are only `flavor = "wasi"|"native"|"web"`. See [directives.md](directives.md).
- Ordinary procedure: `[ export ] procedure` name `(` [parameter list] `)` `;` block `;`.
- Intrinsic: `[ export ] @intrinsic procedure` name `(` [parameter list] `)` `;` — **no** body; AST sets `Intrinsic_Flag` (signature checked in IR).
- Native FFI: `[ export ] @native ( string , string ) procedure` name `(` [parameter list] `)` `;` — **no** body; AST sets `Native_Flag` and stores library/function (quotes stripped).
- Bare `native(…)` procedure headers are not accepted (`native` is an ordinary identifier; use `@intrinsic` / `@native`).
- Call statements: qualified call `MODULE.SUBROUTINE(` [expressions] `);` — callee must contain at least one `.`.
- Types: `integer` / `signed integer` / `unsigned integer` with optional `<8|16|32|64>`; `float` with optional `<32|64>`; `boolean`.
- **Scopes:** scope stack while parsing (usings + parameters → declare parts). No shadowing of usings/locals; no clash with unit name / subroutine names (`Name_Clash` / [`LV00011`](diagnostics.md)). Sibling nested blocks may reuse the same using or local name.

Keywords are case-sensitive. The unit terminator after a unit-level `end` is only `.` (`Full_Stop`). Procedure bodies end with `end;` after the body block. Modules have **no** unit-level `begin`. Extra tokens after a complete unit are `Unexpected_Trailing`. `#if` is **not** allowed inside procedure bodies in this slice. Lexeme `import` is an ordinary identifier (not a keyword); misplaced `import` fails as `Unexpected_Token`. `using … as …` is reserved and not parsed.

## AST shape

**Program** (`Unit_Kind = Program_Unit`):

- A module named `IDENTIFIER`
- Ordered `Using_Declaration` list (may be empty) — unit-leading usings
- One subroutine with the same name
- Body is a **block** (optional usings + locals + statements); return type **unit**; no parameters on the synthetic entry
- Flags: both `Export_Flag` and `Entrypoint_Flag`

**Module** (`Unit_Kind = Module_Unit`):

- A module named the qualified identifier (UTF-8 with `.` separators, e.g. `Foo.Bar`)
- Ordered `Using_Declaration` list (may be empty)
- Zero or more procedures from **active** declarations only. Optional `export` sets `Export_Flag` (not `Entrypoint_Flag`); optional `@intrinsic` sets `Intrinsic_Flag`; optional `@native(…)` sets `Native_Flag` and a present native binding; plain procedures keep flags `0`. Inactive `#if` arms do not appear in the AST.
- Each procedure has unqualified `Name`, `Full_Name` = `ModuleName.ProcedureName`, ordered parameters, Unit return, optional block body (absent/empty when intrinsic/native)
- `Name_Span` on the module covers the whole qualified name

**Call statement:** `Callee_Name` (dotted), `Name_Span`, ordered expression arguments. Call-target resolve runs in **semantics**, not the parser.

**Assignment:** LHS identifier + RHS expression.

**Block / locals / usings:** each block holds ordered using list, local list (name + type + span), and statements (`Call`, `Assignment`, or `Nested_Block`). Nested structure is AST-only; IR flattens locals later ([ir-generator.md](ir-generator.md)). Unit graph collects **all** usings (unit-leading and nested).

### Name rules

- Using module names unique in a scope; using name ≠ unit module name (self-using); nested using must not shadow an enclosing using
- Parameter names unique within a procedure
- Parameter name ≠ module name; ≠ any procedure name in the module
- Procedure name ≠ module name; procedure names unique in the module
- Local names unique within a declare part; must not shadow enclosing locals/parameters; must not reuse the unit name or any subroutine name in the unit
- Clash rules for procedures apply to the **selected** set only (two procedures in mutually exclusive arms may share a name)
- Violations → `Name_Clash` ([`LV00011`](diagnostics.md))

Spans cover names and the whole unit (first token through the final `.`). Optional filenames come from tokenization ([source-locations.md](source-locations.md)).

## Errors

| Code | Meaning |
| --- | --- |
| `Internal_Error` | Compiler bug (listed first) |
| `Unexpected_End_Of_Input` | A token was required but the cursor was at end |
| `Unexpected_Token` | Wrong kind/subtype at the cursor (including bad type sizes such as `float<16>`, or `#if` / `#elsif` / `#else` / `#end` misplaced; also misuse of identifier `import`) |
| `Unexpected_Trailing` | Tokens remain after a complete unit |
| `Name_Clash` | Duplicate or conflicting procedure/parameter/using/local name (selected set only; includes self-using and no-shadow usings/locals) |
| `Invalid_Flavor_Condition` | Flavor string is not exactly `wasi` / `native` / `web` ([`LV00012`](diagnostics.md)) |

Empty input / empty token list reports `Unexpected_End_Of_Input` at a synthetic span `(1,1,1)` when nothing was consumed.
