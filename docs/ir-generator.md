# Compiler IR Generator

`Lovelace.Compiler.Ir_Generator` lowers a frontend AST module into a LIR module. It lives in crate `lovelace_compiler`, which depends on `lovelace_lir`. Frontend AST and types stay separate from LIR; only this package (and tests) reference `Lovelace.Lir.*`.

There is no CLI wiring and no statement lowering in this slice. Empty AST bodies become empty LIR instruction sequences (no `noop`).

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
| Module name | `Modules.Create` then append subroutines |
| Module name span, unit span, filename | `Modules.Set_Origin` (`Module_Origin`) |
| Module flags / depends | flags `0`; no dependencies |
| Each subroutine | `Subroutines.Create` + `Append_Subroutine` |
| Subroutine name | `Signature.Name` |
| Subroutine name span, filename | `Subroutines.Set_Origin` (`Subroutine_Origin`) |
| Return type `Unit` | `Lir.Types.Unit` |
| Parameters | empty sequence |
| `Export_Flag` / `Entrypoint_Flag` | same-named LIR flag bits (via `Has_Export` / `Has_Entrypoint`) |
| Empty statement body | empty instruction sequence |

Origins use [`Lovelace.Common.Source`](source-locations.md). They are in-memory only on LIR; `.lir` / `.tlir` v1.0 do not persist them (see [lir.md](lir.md)).

## Errors

| Code | Meaning |
| --- | --- |
| `Internal_Error` | Compiler bug (listed first): e.g. LIR `Validate` failed after lowering |

Future unhandled frontend type kinds would also use `Internal_Error`. This slice only maps `Unit`.

## Out of scope

- Statement / expression lowering and instruction source maps
- Emitting `No_Operation` for empty bodies
- CLI / `lovelace build`
- Analysis and optimization

WASM / WAT / WIT emission from LIR is implemented separately; see [codegen.md](codegen.md).
