---
name: Intrinsic vs native
overview: "Implement roadmap 1.002 macro step 2 — replace header `native(\"target\", \"key\")` with `@intrinsic` (signature-matched synthesis) and `@native(\"lib\", \"fn\")` (FFI metadata); hard-reject old form; Augusta wasi print becomes `@intrinsic`."
todos:
  - id: "1"
    content: "1. Create GitHub issue with gh issue create (@intrinsic/@native / roadmap 1.002 macro step 2); reuse if equivalent open issue exists; record <n>."
    status: completed
  - id: "2"
    content: "2. Sync main, then gh issue develop <n> --name feature/<n>-intrinsic-vs-native --checkout --base main. Verify with gh issue develop --list <n>."
    status: completed
  - id: "3"
    content: "3. Save this plan as .cursor/plans/<nnn>-intrinsic-vs-native.plan.md with #<n> in the body (rename from 037 if issue number differs)."
    status: completed
  - id: "4"
    content: "4. Diagnostics: Unknown_Intrinsic (LV00025) + Obsolete_Native_Modifier (LV00026); retire emitting LV00021; wire Reporting + diagnostics.md; gnatformat."
    status: completed
  - id: "5"
    content: "5. AST/LIR: Intrinsic_Flag; Native_Binding Library/Function for @native only; text/binary codecs + Validate; LIR AUnit; gnatformat."
    status: completed
  - id: "6"
    content: "6. Parser: [export] @intrinsic|@native(\"…\",\"…\") procedure; hard-reject keyword native(…); AUnit; gnatformat."
    status: completed
  - id: "7"
    content: "7. Intrinsics table + IR gen: match module+name+params+return; unknown @intrinsic → LV00025; lower @native binding; AUnit; gnatformat."
    status: pending
  - id: "8"
    content: "8. Backend: synthesize print-integer on Intrinsic_Flag + table hit (shared matcher); @native → empty noop body for now; update Test_Native_Print_Integer; gnatformat."
    status: pending
  - id: "9"
    content: "9. Augusta wasi print → @intrinsic; delete samples/native/NativePrint.love; update samples.md, augusta.md, grammar/parser/ir/codegen/lir docs; lock roadmap step 2."
    status: pending
  - id: "10"
    content: "10. Run all tests (scripts/run-tests.ps1); HelloPrint via Augusta is the intrinsic smoke."
    status: pending
  - id: "11"
    content: "11. Push (proxy env cleared) and open a PR with gh pr create."
    status: pending
isProject: false
---

# `@intrinsic` vs `@native(…)` (roadmap 1.002 macro step 2)

#37 — [Compiler: @intrinsic vs @native (roadmap 1.002 macro step 2)](https://github.com/sanelli/lovelace/issues/37)

Branch: `feature/37-intrinsic-vs-native` (linked to #37; created from `main` via `gh issue develop`).

Plan file: [`.cursor/plans/037-intrinsic-vs-native.plan.md`](037-intrinsic-vs-native.plan.md).

Roadmap: [docs/roadmap/1.002-roadmap-replace-synthesized-print.md](../../docs/roadmap/1.002-roadmap-replace-synthesized-print.md) § Macro step 2.

**How to execute:** one numbered step per invocation (or an explicit consecutive range). Do not skip the envelope (1–3) or the closing tests/PR. After each Ada edit step, run `alr exec -- gnatformat` on touched files and build/run the relevant test crate before moving on.

## Locked decisions

- **Forms (only):**
  - `export @intrinsic procedure Name(…);` — **no** arguments on `@intrinsic`
  - `export @native("shared-library-name", "function-name") procedure Name(…);`
  - Modifier order: optional `export`, then exactly one of `@intrinsic` / `@native(…)`, then `procedure` (same spirit as today’s `[export] native(…) procedure`)
- **Hard-reject** procedure-header keyword `native("target", "key")` in this PR — **no** compatibility window. Parser diagnostic `Obsolete_Native_Modifier` (`LV00026`) with a message that points at `@intrinsic` / `@native`
- **`@intrinsic` matching:** closed table keyed by **module name + procedure name + parameter types + return type**. Unknown signature → **`Unknown_Intrinsic` (`LV00025`)** — never treat as an ordinary empty body
- **Sole synthesizer entry for this step:**

  | Module | Name | Params | Return | Backend |
  | --- | --- | --- | --- | --- |
  | `augusta.std.io` | `print` | `integer` (one) | `Unit` | existing decimal + WASI 0.3 stdout synthesis ([`Backend.Native_Print`](../../compiler/src/lovelace-compiler-backend-native_print.ads)) |

- **Delete** [`samples/native/NativePrint.love`](../../samples/native/NativePrint.love) (and its `docs/samples.md` row). Intrinsic coverage is **Augusta + HelloPrint** (integration), not a second `.love` module
- **`@native`:** parse + AST + LIR metadata only; **no** shared-library loading. Backend emits an **empty noop** core body (same as a Lovelace empty `begin end`). Full FFI → later [1.004](../../docs/roadmap/1.004-roadmap-print-integer-native.md) / [Z.001](../../docs/roadmap/Z.001-roadmap-invoke-native-code.md)
- **`@intrinsic` / `@native` are not general attributes** — only these two procedure-header prefixes; broader attribute syntax → [2.012](../../docs/roadmap/2.012-roadmap-advanced-syntax-attributes.md)
- **Tokenizer:** `@intrinsic` / `@native` remain **identifiers** (existing `@` prefix). No new keyword tokens for them. Keep keyword `native` so the obsolete form is easy to diagnose
- **Mutually exclusive:** cannot combine `@intrinsic` with `@native`, or either with a `begin`…`end` body; cannot set both `Intrinsic_Flag` and `Native_Flag` on one subroutine
- **Out of scope:** `PrintUTF8Character`, retiring the print synthesizer, working `@native` on every flavor, literal/`boolean`/assignment steps

Example Augusta wasi arm after this step:

```love
#if flavor = "wasi"

{ TEMPORARY: print is @intrinsic until Lovelace can format digits
  in-language (roadmap 1.002). }
export @intrinsic procedure print(value : integer);

#end
```

## Architecture

```mermaid
flowchart TD
  src[".love procedure header"]
  parse["Parser"]
  obsolete["Obsolete_Native_Modifier LV00026"]
  astI["AST Intrinsic_Flag"]
  astN["AST Native_Flag + Library/Function"]
  ir["IR generator"]
  table["Intrinsics table"]
  unk["Unknown_Intrinsic LV00025"]
  lirI["LIR Intrinsic_Flag empty body"]
  lirN["LIR Native_Flag + binding"]
  be["Backend lowering"]
  synth["Native_Print.Synthesize"]
  noop["Empty noop core fn"]

  src --> parse
  parse -->|"keyword native("| obsolete
  parse -->|"@intrinsic"| astI
  parse -->|"@native"| astN
  astI --> ir
  astN --> ir
  ir --> table
  table -->|miss| unk
  table -->|hit| lirI
  ir -->|@native| lirN
  lirI --> be
  lirN --> be
  be -->|table hit| synth
  be -->|@native| noop
```

## Steps

### 1–3. Envelope

**Done:** issue #37, branch `feature/37-intrinsic-vs-native`, this plan file.

### 4. Diagnostics

Files: [`compiler/src/lovelace-compiler-error_codes.ads`](../../compiler/src/lovelace-compiler-error_codes.ads) / `.adb`, parser + IR generator error enums, [`lovelace-compiler-reporting.adb`](../../compiler/src/lovelace-compiler-reporting.adb), [`docs/diagnostics.md`](../../docs/diagnostics.md).

| Code | Ada enum | When |
| --- | --- | --- |
| `LV00025` | `Unknown_Intrinsic` | `@intrinsic` signature not in closed table (IR) |
| `LV00026` | `Obsolete_Native_Modifier` | keyword `native(…)` procedure header (parser) |

Stop **emitting** `LV00021` / `Unknown_Native_Binding` (old wasi target/key closed set). Keep the enum/label in the table as retired/unused so numbers stay stable (document “retired” in `diagnostics.md`).

### 5. AST + LIR flags / binding reshape

**AST** ([`lovelace-compiler-ast.ads`](../../compiler/src/lovelace-compiler-ast.ads)):

- Add `Intrinsic_Flag` (new bit; do not overload `Native_Flag`)
- Keep `Native_Flag` for `@native` only
- Rename binding fields `Target`/`Key` → `Library` / `Function_Name` (or equivalent clear names). Present only for `@native`

**LIR** ([`lovelace-lir-subroutines.ads`](../../lir/src/lovelace-lir-subroutines.ads) + text/binary codecs + `Validate`):

- `Intrinsic_Flag := 2**3`
- `Native_Flag` + `Set_Native_Binding(Library, Function_Name)` for FFI
- `Set_Intrinsic` (or flags-only) for `@intrinsic` — **no** binding strings
- Validate: flag ⇔ binding rules; intrinsic/native mutually exclusive; either ⇒ empty instruction body; neither with `Entrypoint_Flag`
- Text `.tlir`: emit bare `intrinsic` flag and/or `(native "lib" "fn")` as appropriate; document in [`docs/lir.md`](../../docs/lir.md)
- Binary `.lir` v1.0 additive: `Intrinsic_Flag` in flags word is enough for intrinsics; `native_present` + two strings only when `Native_Flag`
- Update LIR AUnit (validation / text / binary cases that used `wasi`/`native-print-integer`)

### 6. Parser

[`lovelace-compiler-parser.adb`](../../compiler/src/lovelace-compiler-parser.adb) `Parse_Procedure_Declaration`:

1. Optional `export`
2. If keyword `native` → `Obsolete_Native_Modifier` (`LV00026`), recover
3. Else if identifier lexeme `@intrinsic` → `Intrinsic_Flag`; no `(…)`
4. Else if identifier lexeme `@native` → parse `(` string `,` string `)` → `Native_Flag` + binding
5. `procedure` … `;` then: intrinsic/native ⇒ empty body / return; else `begin`…`end;`

Reject `@intrinsic`/`@native` + `begin`. Reject both attributes. AUnit: replace [`Test_Native_Procedure`](../../compiler/tests/src/lovelace-compiler-tests-parser.adb); add obsolete-form failure; keep keyword tokenization tests (lexeme still `native`).

Tokenizer: no scan change required beyond existing `@` identifiers / `native` keyword.

### 7. Intrinsics table + IR generator

New small package (e.g. `Lovelace.Compiler.Intrinsics`) shared by IR gen and backend:

- `function Match_Intrinsic (Module_Name, Subroutine_Name : String; …) return Intrinsic_Kind_Option`
- Closed set: only `augusta.std.io` / `print` / one `integer` param / `Unit` → `Print_Integer_Stdout` (name TBC)

IR gen ([`lovelace-compiler-ir_generator.adb`](../../compiler/src/lovelace-compiler-ir_generator.adb)):

- `@intrinsic`: match table using **containing module name** + subroutine signature; miss → `Unknown_Intrinsic`; hit → LIR `Intrinsic_Flag`, empty body (skip statement lower)
- `@native`: `Set_Native_Binding(Library, Function_Name)`; **no** closed-set check
- Remove `Native_Binding_Allowed` wasi/key gate and `Unknown_Native_Binding` emission

AUnit: unknown `@intrinsic` on e.g. `module Lib; export @intrinsic procedure print(value : integer);` → `LV00025`; success path can parse/lower a synthetic `module augusta.std.io` unit in the fixture (or rely on integration for success and unit-test the matcher + failure)

### 8. Backend

[`lovelace-compiler-backend-lowering.adb`](../../compiler/src/lovelace-compiler-backend-lowering.adb):

- If `Intrinsic_Flag`: call shared `Match_Intrinsic` on LIR module + subroutine; on `Print_Integer_Stdout` → existing `Native_Print.Synthesize` + `Enable_Wasi_Stdout`; on miss → hard error (should be unreachable if IR checked)
- If `Native_Flag` (`@native`): leave empty instruction body / emit noop core function (document stub)
- Retarget [`Test_Native_Print_Integer`](../../compiler/tests/src/lovelace-compiler-tests-backend.adb) to build an `augusta.std.io` LIR module with `Intrinsic_Flag` on `print` (no `Set_Native_Binding` wasi/key)

### 9. Augusta, samples, docs, roadmap

- [`augusta/augusta.std.io.love`](../../augusta/augusta.std.io.love): wasi arm → `export @intrinsic procedure print(value : integer);`; refresh TEMPORARY `{…}` comment
- **Delete** `samples/native/NativePrint.love`; remove row from [`docs/samples.md`](../../docs/samples.md); remove empty `samples/native/` if unused
- Docs: [`compilation-unit-grammar.md`](../../docs/compilation-unit-grammar.md), [`parser.md`](../../docs/parser.md), [`token-grammar.md`](../../docs/token-grammar.md), [`ir-generator.md`](../../docs/ir-generator.md), [`codegen.md`](../../docs/codegen.md), [`lir.md`](../../docs/lir.md) / [`lir-binary.md`](../../docs/lir-binary.md), [`augusta.md`](../../docs/augusta.md), [`diagnostics.md`](../../docs/diagnostics.md)
- Roadmap 1.002 step 2: lock decisions + status with #37; mark step 1 **Done** if still “In progress”

### 10. Full tests

```bash
pwsh scripts/run-tests.ps1
# HelloPrint (AUGUSTA_HOME) is the end-to-end @intrinsic smoke
```

### 11. Push / PR

Clear proxy env, `git push -u origin HEAD`, `gh pr create` closing #37, referencing roadmap 1.002 step 2.

## Non-goals (reminders)

- Do not implement `PrintUTF8Character`, digit loops in Augusta, or remove the print synthesizer (later 1.002 steps)
- Do not implement real `@native` shared-library invoke
- Do not land literal reform / boolean / `:=` / operators / if / loop in this PR
