---
name: Numeric types procedures
overview: Add Lovelace numeric types and literals, module-only procedures with Ada-style typed parameters, persist parameter names in LIR (v1.0 layout, no version bump), drop i128/u128/f16 from language and LIR, and emit all remaining sizes through WASM/WAT with a documented core mapping.
todos:
  - id: "1"
    content: "1. Create GitHub issue with gh issue create (numeric types, literals, module procedures); reuse if equivalent open issue exists; record <n>."
    status: completed
  - id: "2"
    content: "2. Sync main, then gh issue develop <n> --name feature/<n>-numeric-types-procedures --checkout --base main. Verify with gh issue develop --list <n>."
    status: completed
  - id: "3"
    content: "3. Save this plan as .cursor/plans/<n>-numeric-types-procedures.plan.md with #<n> in the body."
    status: completed
  - id: "4"
    content: "4. LIR: remove I128/U128/F16; add named parameters to signatures and .lir/.tlir (version stays 1.0); update LIR docs/tests/rules."
    status: completed
  - id: "5"
    content: "5. Tokenizer: procedure/integer/float/signed/unsigned keywords, type/list punctuation, integer and float literal tokens + AUnit tests."
    status: completed
  - id: "6"
    content: "6. Frontend Types (Integer/Float), AST procedure parameters and Full_Name, Literals interpreter + AUnit tests."
    status: completed
  - id: "7"
    content: "7. Parser: module procedure declarations, Ada-style parameter lists, builtin type names, name-clash diagnostics + codes."
    status: completed
  - id: "8"
    content: "8. IR Generator: map type expressions and named parameters into LIR signatures."
    status: pending
  - id: "9"
    content: "9. Backend: lower all remaining numeric param sizes to core WASM/WAT functypes; document WIT mapping; update backend tests."
    status: pending
  - id: "10"
    content: "10. Samples, docs (grammar/tokenizer/parser/lir/codegen/diagnostics), and remaining AUnit/CLI coverage."
    status: pending
  - id: "11"
    content: "11. Run all existing tests (nested AUnit crates / workspace)."
    status: pending
  - id: "12"
    content: "12. Push (proxy env cleared) and open a PR with gh pr create."
    status: pending
isProject: false
---

# Numeric types, literals, and module procedures

#19 — [Compiler: numeric types, literals, and module procedures](https://github.com/sanelli/lovelace/issues/19)

Branch: `feature/19-numeric-types-procedures` (linked to #19; created from `main` via `gh issue develop`).

Plan file: [`.cursor/plans/19-numeric-types-procedures.plan.md`](19-numeric-types-procedures.plan.md).

Depends on modules on `main` ([#17](https://github.com/sanelli/lovelace/issues/17)). Branch from current `main` only.

## Locked decisions

- **Parameter lists (Ada-style):** commas between names in a group; semicolons between typed groups.
- **`begin` has no trailing `;`.** Body is `begin` … `end;`.
- **Procedures only inside `module` units** (not `program`). No export/entrypoint syntax yet → procedure flags `0`.
- **Keywords (case-sensitive):** `procedure`, `integer`, `float`, `signed`, `unsigned` (plus existing `module` / `begin` / `end` / `program`).
- **LIR parameter names:** store names + types in signatures and `.lir` / `.tlir`; **format version stays 1.0**.
- **Drop for now from language and LIR:** `integer<128>`, `unsigned integer<128>`, `float<16>` and LIR `I128` / `U128` / `F16`.
- **Literals:** tokenize + interpret + test; **not** used in calls/bodies yet.
- **Type names:** parse only builtin forms this slice (not dotted paths). Shape `Type_Expression` so a future path/`Named` kind can be added without reshaping Integer/Float.

Example:

```love
module MyModule;
   procedure Whatever(x : integer; y, z : float<32>);
   begin
   end;
end.
```

## Surface grammar (this slice)

```ebnf
module_unit              = module_header , { procedure_declaration } , "end" , "." ;
procedure_declaration    = procedure_header , "begin" , "end" , ";" ;
procedure_header         = "procedure" , identifier , "(" , [ parameter_list ] , ")" , ";" ;
parameter_list           = parameter_group , { ";" , parameter_group } ;
parameter_group          = identifier , { "," , identifier } , ":" , type_name ;
type_name                = integer_type | float_type ;
integer_type             = [ "signed" | "unsigned" ] , "integer" , [ "<" , integer_size , ">" ] ;
integer_size             = "8" | "16" | "32" | "64" ;
float_type               = "float" , [ "<" , float_size , ">" ] ;
float_size               = "32" | "64" ;
```

Defaults: omitted signedness → signed; omitted integer size → 32; omitted float size → 32. Programs stay unchanged (no procedures).

## Name rules

- Parameter names unique within the procedure.
- Parameter name ≠ module name; ≠ any subroutine name in the module.
- Procedure name ≠ module name; procedure names unique in the module.
- Store AST **full name** `ModuleName.ProcedureName` for later use. LIR subroutine name stays the unqualified procedure id.

## Type mapping

| Lovelace | LIR | Core WASM | WIT (when exported later) |
|---|---|---|---|
| integer / signed integer / integer<32> | I32 | i32 | s32 |
| integer<8> | I8 | i32 | s8 |
| integer<16> | I16 | i32 | s16 |
| integer<64> | I64 | i64 | s64 |
| unsigned integer / unsigned integer<32> | U32 | i32 | u32 |
| unsigned integer<8> | U8 | i32 | u8 |
| unsigned integer<16> | U16 | i32 | u16 |
| unsigned integer<64> | U64 | i64 | u64 |
| float / float<32> | F32 | f32 | f32 |
| float<64> | F64 | f64 | f64 |

Small integers widen to core i32/i64. Procedures are not exported this slice, so WIT export lines stay as today for programs; **core** functypes carry mapped parameter types.

## Literals

- **Integer token:** optional `+`/`-`, optional `#BASE#` (2/8/10/16), valid digits for base, optional `s`/`u`, optional size 8/16/32/64.
- **Float token:** optional `+`/`-`, digits, `.`, optional fraction, optional `e`/`E` with optional signed exponent (`7.`, `3.4E3`).
- Interpret lexemes in `Lovelace.Compiler.Literals` (Result-shaped); AUnit tests; not wired into bodies/calls.

## Envelope (agent workflow)

1. Create GitHub issue with `gh issue create`; record `#19`.
2. Sync `main`, then `gh issue develop 19 --name feature/19-numeric-types-procedures --checkout --base main`. Verify with `gh issue develop --list 19`.
3. Save this plan as [`.cursor/plans/19-numeric-types-procedures.plan.md`](19-numeric-types-procedures.plan.md) with `#19` in the body.
4. LIR: drop I128/U128/F16; named params in signatures/codecs (v1.0); docs/tests/rules.
5. Tokenizer: keywords, punctuation, integer/float literals + tests.
6. Frontend Types (Integer/Float), AST params + Full_Name, Literals package + tests.
7. Parser: procedures, Ada param lists, builtin types, name-clash diagnostics.
8. IR Generator: map types and named parameters to LIR.
9. Backend: lower all remaining numeric params to core WASM/WAT; document WIT mapping; tests.
10. Samples, docs, remaining AUnit/CLI coverage.
11. Run all existing nested AUnit / workspace tests.
12. Push (proxy cleared) and `gh pr create`.

## Implementation notes

### LIR ([`lir/`](../../lir/), [`.cursor/rules/lir.mdc`](../rules/lir.mdc))

- `Value_Type` becomes `Unit, I8, I16, I32, I64, U8, U16, U32, U64, F32, F64` (codes `0..10`).
- Replace unnamed `Parameter_Types` with ordered `{ Name; The_Type }` records; `Validate` requires non-empty unique names.
- Binary: per parameter → encoded string name + `u8` type. Text: `(param "x" i32 "y" f32)`; omit when empty.

### Tokenizer ([`tokens.ads`](../../compiler/src/lovelace-compiler-tokens.ads), [`tokenizer.adb`](../../compiler/src/lovelace-compiler-tokenizer.adb))

- Keywords + punctuation `(` `)` `,` `:` `<` `>`.
- `Integer_Literal` / `Float_Literal` kinds; longest-match so `1.0` is float.

### Frontend

- [`Types`](../../compiler/src/lovelace-compiler-types.ads): `Unit | Integer | Float` with size/signedness; document future path kind.
- [`Ast`](../../compiler/src/lovelace-compiler-ast.ads): parameter sequence + `Full_Name`; Unit return for procedures.
- New `Literals` package for lexeme interpretation.

### Parser ([`parser.adb`](../../compiler/src/lovelace-compiler-parser.adb))

- After module header: `{ procedure_declaration }` then `end` `.`.
- Reject bad sizes (`float<16>`, `integer<128>`) with clear diagnostics.
- New `LV#####` codes for name clashes as needed.

### IR Generator / Backend

- Map AST params → LIR named params; exhaustive type map.
- Extend `Core_Function` with core param types; emit functypes beyond `[]->[]` / `[]->[i32]`.
- Non-Unit return still `Unsupported_Type`. `_start` unchanged.

### Out of scope

Variables, functions, casts, calls/passing literals, aggregates, dotted user types, export syntax, re-adding i128/u128/f16.
