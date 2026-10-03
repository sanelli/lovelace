# Compiler IR Generator

`Lovelace.Compiler.Ir_Generator` lowers a frontend AST module into a LIR module. It lives in crate `lovelace_compiler`, which depends on `lovelace_lir`. Frontend AST and types stay separate from LIR; only this package (and tests) reference `Lovelace.Lir.*`.

The CLI (`lovelace build`) calls Tokenize → Parse → `Generate` → `Lir.Binary.Write`, then the backends; see [cli.md](cli.md). This package itself has no statement lowering beyond empty bodies (no `noop`).

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). AST input comes from [parser.md](parser.md). LIR shapes and codecs: [lir.md](lir.md). Source locations: [source-locations.md](source-locations.md).

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
| `False` | `Error` — `Internal_Error` with a UTF-8 detail string |

Handle both discriminants. Do not read `The_Module` when `Ok` is `False`.

After building, `Generate` calls `Lovelace.Lir.Modules.Validate`. A validation failure is reported as `Internal_Error` (the frontend should only produce validatable shapes).

## Mapping (this slice)

| Frontend (`Ast` / `Types`) | LIR (`Modules` / `Subroutines` / `Types`) |
| --- | --- |
| Module name (including dotted names) | `Modules.Create` then append subroutines |
| Module name span, unit span, filename | `Modules.Set_Origin` (`Module_Origin`) |
| `Unit_Kind` | not stored in LIR (frontend only) |
| `Full_Name` | not stored in LIR (frontend only; LIR keeps the unqualified procedure name) |
| Module flags / depends | flags `0`; no dependencies |
| Each subroutine | `Subroutines.Create` + `Append_Subroutine` |
| Subroutine name | `Signature.Name` (unqualified) |
| Subroutine name span, filename | `Subroutines.Set_Origin` (`Subroutine_Origin`) |
| Return type `Unit` | `Lir.Types.Unit` |
| Parameters (name + type) | named LIR parameters (same order) |
| `Integer` / `Float` type expressions | LIR `I8`…`I64` / `U8`…`U64` / `F32` / `F64` (see table below) |
| `Export_Flag` / `Entrypoint_Flag` | same-named LIR flag bits (via `Has_Export` / `Has_Entrypoint`) |
| Empty statement body | empty instruction sequence |

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

Empty Lovelace modules (`module Name; end.`) lower to LIR modules with **zero** subroutines. Module procedures with parameters lower to LIR signatures with those named types (flags remain `0`).

Origins use [`Lovelace.Common.Source`](source-locations.md). They are copied onto LIR modules and subroutines and **persisted** in `.lir` / `.tlir` (format version numbers remain **1.0**; see [lir.md](lir.md)).

## Errors

| Code | Meaning |
| --- | --- |
| `Internal_Error` | Compiler bug (listed first): e.g. LIR `Validate` failed after lowering |

## Out of scope

- Statement / expression lowering and instruction source maps
- Emitting `No_Operation` for empty bodies
- CLI / `lovelace build`
- Analysis and optimization

WASM / WAT / WIT emission from LIR is implemented separately; see [codegen.md](codegen.md).
