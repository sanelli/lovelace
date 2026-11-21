# Compiler IR Generator

`Lovelace.Compiler.Ir_Generator` lowers a frontend AST module into a LIR module. It lives in crate `lovelace_compiler`, which depends on `lovelace_lir`. Frontend AST and types stay separate from LIR; only this package (and tests) reference `Lovelace.Lir.*`.

The CLI (`lovelace build`) calls Tokenize → Parse → **Semantics** → `Generate` → `Lir.Binary.Write`, then the backends; see [cli.md](cli.md). Semantics (environment, definite assignment, typecheck, call-target / overload resolve, unused warnings) runs **before** IR and owns `LV00014` / `LV00017` / `LV00018` / `LV00026`–`LV00029` / `LV00031`–`LV00033` — rules: [semantics.md](semantics.md). IR assumes a resolved, well-typed AST and only lowers.

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). AST input comes from [parser.md](parser.md). LIR shapes and codecs: [lir.md](lir.md). Source locations: [source-locations.md](source-locations.md).

## Module path and unit graph

Multi-unit loading (roadmap [1.001](roadmap/1.001-roadmap-print-integer-wasi.md) step 5) uses:

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Module_Path` | Dotted name → mixed slash/dot `.love` candidates; search roots; Augusta slot |
| `Lovelace.Compiler.Unit_Graph` | Transitive using closure (`Load`); cycles / unknown / ambiguous diagnostics |

Path candidates for `a.b.c`: `a/b/c.love`, `a/b.c.love`, `a.b/c.love`, `a.b.c.love` (stable mask order). Search roots and Augusta env vars are documented in [cli.md](cli.md). The unit graph collects **all** usings in the AST (unit-leading **and** nested block usings).

## Pipeline

```text
UTF-8 .love  →  Tokenize  →  Parse  →  Semantics  →  Generate  →  Lir.Modules.Module
                                                                              ↓
                                                                    Backend (WASM / WAT / WIT)
```

Callers parse and run semantics first. `Generate` does not call `Tokenize` or `Parse`. Codegen from LIR: [codegen.md](codegen.md).

## API

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Ir_Generator` | `Generate`, `Generate_Result`, `Ir_Generator_Error` |

```ada
function Generate (The_Module : Ast.Module) return Generate_Result;
function Generate (Units : Unit_Graph.Compilation_Set) return Generate_Result;
```

The single-module overload wraps `The_Module` as a one-element compilation set. The multi-unit overload flattens root-first units into **one** LIR module (dependency procedures mangled as `Module.Proc`).

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
| All usings in the unit (unit-leading + nested; unique module names) | `Append_Dependency` for each used module name |
| Each subroutine | `Subroutines.Create` + body instructions + `Append_Subroutine` |
| Subroutine name | `Signature.Name` (unqualified) |
| Subroutine name span, declaration span, filename | `Subroutines.Set_Origin` (`Subroutine_Origin`) |
| Return type `Unit` | `Lir.Types.Unit` |
| Parameters (name + type) | named LIR parameters (same order) |
| `Integer` / `Float` / `Boolean` type expressions | LIR `I8`…`I64` / `U8`…`U64` / `F32` / `F64` / `I32` for boolean (see table below) |
| `Export_Flag` / `Entrypoint_Flag` / `Native_Flag` / `Intrinsic_Flag` | same-named LIR flag bits |
| `@native("lib", "fn")` binding | LIR `Set_Native_Binding` (empty instruction body; no statement lower; no closed-set check) |
| `@intrinsic` | LIR `Set_Intrinsic` after closed-table match (empty body; no statement lower) |
| Empty statement body | empty instruction sequence (no `noop`) |
| Block locals (including nested `declare`) | Flattened into LIR `Append_Local` in DFS / preorder (nested scopes disappear) |
| Assignment `id := expr` | Evaluate RHS then `Local_Set` (1-based; params first, then flattened locals) |
| Identifier expression | `Local_Get` (same 1-based index map) |
| Integer / boolean literal expression | `Constant_I32` |
| Same-unit / cross-module `MODULE.SUBROUTINE(…)` | Push args then `Call` (1-based subroutine index); select overload by name + argument types (assignability); **semantics already resolved** |
| Procedure LIR name | Source name on the root unit (`Proc`); dependency procedures `Module.Proc`. Overloads **share** the name; distinction is the index (see LIR/TLIR `(index)` / binary preamble) |

### Intrinsics (this slice)

Closed table (`Lovelace.Compiler.Intrinsics`): only `augusta.std.io` / `print` / one `integer` param / `Unit` → `Print_Integer_Stdout`. Unknown `@intrinsic` → `Unknown_Intrinsic` (`LV00025`). The backend synthesizes the WASI 0.3 stdout body for that kind (see [codegen.md](codegen.md)). `@native` stores library/function metadata only (FFI invoke later).

### Call lowering (this slice)

Call-target resolve (module in scope via `using`, subroutine exists, `Export_Flag` for cross-module) is **semantics**, not IR. Failures there → `Call_Without_Using` (`LV00017`), `Not_Exported` (`LV00018`), or `Unresolved_Call` (`LV00014`).

IR still checks argument lowering details where needed. **Integer** formals (signed/unsigned size ≤ 32) take integer literals as `Constant_I32` (negative literals rejected for unsigned). **`boolean`** formals take only `true` / `false` → `Constant_I32` **1** / **0**. Identifier args lower via `Local_Get`. Failures → `Invalid_Arguments` (`LV00015`) where still emitted from IR.

### Type map

| Frontend | LIR |
| --- | --- |
| `boolean` | `I32` (language `false` ↔ 0; `true` ↔ nonzero; literals emit 0 / 1) |
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

Empty Lovelace modules (`module Name; end.`) lower to LIR modules with **zero** subroutines. Using names (all usings in the unit) become LIR `Dependencies` (backend still ignores them).

Origins use [`Lovelace.Common.Source`](source-locations.md). They are copied onto LIR modules and subroutines and **persisted** in `.lir` / `.tlir` (format version numbers remain **1.0**; see [lir.md](lir.md)).

## Errors

| Code | LV | Meaning |
| --- | --- | --- |
| `Internal_Error` | `LV00001` | Compiler bug (e.g. LIR `Validate` failed after lowering) |
| `Invalid_Arguments` | `LV00015` | Wrong arity, out-of-range literal, or unsupported formal |
| `Unknown_Intrinsic` | `LV00025` | `@intrinsic` signature is not in the closed intrinsic table |

Call resolve diagnostics (`LV00014` / `LV00017` / `LV00018`) and name/type/DA/unused codes are **not** produced by IR — see [diagnostics.md](diagnostics.md) (Semantics stage).

## Out of scope

- Emitting `No_Operation` for empty bodies
- Operators / general expressions beyond literal + identifier
- Analysis and optimization (beyond what semantics already did)

WASM / WAT / WIT emission from LIR (including native intrinsic synthesis) is implemented separately; see [codegen.md](codegen.md).
