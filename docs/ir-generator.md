# Compiler IR Generator

`Lovelace.Compiler.Ir_Generator` lowers a frontend AST module into a LIR module. It lives in crate `lovelace_compiler`, which depends on `lovelace_lir`. Frontend AST and types stay separate from LIR; only this package (and tests) reference `Lovelace.Lir.*`.

The CLI (`lovelace build`) calls Tokenize → Parse → `Generate` → `Lir.Binary.Write`, then the backends; see [cli.md](cli.md).

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). AST input comes from [parser.md](parser.md). LIR shapes and codecs: [lir.md](lir.md). Source locations: [source-locations.md](source-locations.md).

## Module path and unit graph

Multi-unit loading (roadmap step 5) uses:

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Module_Path` | Dotted name → mixed slash/dot `.love` candidates; search roots; Augusta slot |
| `Lovelace.Compiler.Unit_Graph` | Transitive import closure (`Load`); cycles / unknown / ambiguous diagnostics |

Path candidates for `a.b.c`: `a/b/c.love`, `a/b.c.love`, `a.b/c.love`, `a.b.c.love` (stable mask order). Search roots and Augusta env vars are documented in [cli.md](cli.md). Cross-module call lowering still lands in a later step of the same milestone; same-unit resolve below remains the current `Generate` behavior.

## Pipeline

```text
UTF-8 .love  →  Tokenize  →  Parse  →  Ast.Module  →  Generate  →  Lir.Modules.Module
                                                                        ↓
                                                              Backend (WASM / WAT / WIT)
```

Callers parse first. `Generate` does not call `Tokenize` or `Parse`. Codegen from LIR: [codegen.md](codegen.md).

## API

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Ir_Generator` | `Generate`, `Generate_Result`, `Ir_Generator_Error` |

```ada
function Generate (The_Module : Ast.Module) return Generate_Result;
```

`Generate_Result` is a LIR module **or** an error, not both:

| `Ok` | Payload |
| --- | --- |
| `True` | `The_Module` — generated LIR module |
| `False` | `Error` — code, span, UTF-8 detail |

Handle both discriminants. Do not read `The_Module` when `Ok` is `False`.

After building, `Generate` calls `Lovelace.Lir.Modules.Validate`. A validation failure is reported as `Internal_Error`.

## Mapping (this slice)

| Frontend (`Ast` / `Types`) | LIR (`Modules` / `Subroutines` / `Types`) |
| --- | --- |
| Module name (including dotted names) | `Modules.Create` then append subroutines |
| Module name span, unit span, filename | `Modules.Set_Origin` (`Module_Origin`) |
| `Unit_Kind` | not stored in LIR (frontend only) |
| `Full_Name` | not stored in LIR (frontend only; LIR keeps the unqualified procedure name) |
| Module flags | flags `0` |
| Ordered `Import_Declaration` list | `Append_Dependency` for each imported module name (source order) |
| Each subroutine | `Subroutines.Create` + body instructions + `Append_Subroutine` |
| Subroutine name | `Signature.Name` (unqualified) |
| Subroutine name span, filename | `Subroutines.Set_Origin` (`Subroutine_Origin`) |
| Return type `Unit` | `Lir.Types.Unit` |
| Parameters (name + type) | named LIR parameters (same order) |
| `Integer` / `Float` type expressions | LIR `I8`…`I64` / `U8`…`U64` / `F32` / `F64` (see table below) |
| `Export_Flag` / `Entrypoint_Flag` | same-named LIR flag bits (via `Has_Export` / `Has_Entrypoint`) |
| Empty statement body | empty instruction sequence (no `noop`) |
| Same-unit `MODULE.SUBROUTINE(…)` | `Constant_I32` × N then `Call` (1-based local index) |

### Call resolution (this slice)

- Callee must be `UnitName.ProcedureName` where `UnitName` equals the compilation-unit module name and `ProcedureName` is a local procedure.
- Cross-module / import-based resolution is deferred (roadmap step 5) → `Unresolved_Call` (`LV00014`).
- Argument count must match formals; each formal must accept an `i32` constant (signed/unsigned integer size ≤ 32). Negative literals are rejected for unsigned formals. Failures → `Invalid_Arguments` (`LV00015`).

### Type map

| Frontend | LIR |
| --- | --- |
| `integer` / `signed integer` / `integer<32>` | `I32` |
| `integer<8>` / `signed integer<8>` | `I8` |
| `integer<16>` | `I16` |
| `integer<64>` | `I64` |
| `unsigned integer` / `unsigned integer<32>` | `U32` |
| `unsigned integer<8>` | `U8` |
| `unsigned integer<16>` | `U16` |
| `unsigned integer<64>` | `U64` |
| `float` / `float<32>` | `F32` |
| `float<64>` | `F64` |

Empty Lovelace modules (`module Name; end.`) lower to LIR modules with **zero** subroutines. Leading `import` names become LIR `Dependencies` (backend still ignores them).

Origins use [`Lovelace.Common.Source`](source-locations.md). They are copied onto LIR modules and subroutines and **persisted** in `.lir` / `.tlir` (format version numbers remain **1.0**; see [lir.md](lir.md)).

## Errors

| Code | LV | Meaning |
| --- | --- | --- |
| `Internal_Error` | `LV00001` | Compiler bug (e.g. LIR `Validate` failed after lowering) |
| `Unresolved_Call` | `LV00014` | Call target is not a same-unit procedure |
| `Invalid_Arguments` | `LV00015` | Wrong arity, out-of-range literal, or unsupported formal |

## Out of scope

- Multi-unit / import-gated call resolution
- Emitting `No_Operation` for empty bodies
- Locals, assignment, non-literal arguments
- Analysis and optimization

WASM / WAT / WIT emission from LIR is implemented separately; see [codegen.md](codegen.md).
