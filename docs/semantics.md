# Semantic analysis

`Lovelace.Compiler.Semantics` runs **after parse** and **before IR** on the compilation set from `Unit_Graph.Load`. It owns name resolution / scopes, call-target resolve, definite assignment, `Lovelace_Type` checking, and unused-variable warnings. IR assumes a unit set that passed this stage without **errors** (warnings alone do not block IR).

Pipeline: [parser.md](parser.md) → **semantics** → [ir-generator.md](ir-generator.md). Codes: [diagnostics.md](diagnostics.md). CLI promote/suppress: [cli.md](cli.md). Grammar / using scopes: [compilation-unit-grammar.md](compilation-unit-grammar.md). Locked design: [roadmap 1.002 step 6](roadmap/1.002-roadmap-replace-synthesized-print.md).

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md).

## Packages

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Semantics` | `Analyze` entry; error vs warning partition |
| `…Semantics.Environment` | Scope stack: locals, parameters, modules via `using`, unit subroutines |
| `…Semantics.Resolve` | Call-target resolve (`MODULE.SUBROUTINE`) |
| `…Semantics.Definite_Assignment` | Assigned-bit tracker per variable slot |
| `…Semantics.Lovelace_Types` | Semantic type model (`Lovelace_Type`) |
| `…Semantics.Typecheck` | Assignability / implicit-cast queries |
| `…Semantics.Unused` | Unused_Variable / Unused_Assignment |
| (environment `Used` flag) | Unused_Using for module bindings via `using` |

```ada
function Analyze (Units : Unit_Graph.Compilation_Set) return Analysis_Result;
--  Errors fail the build; Warnings are non-fatal unless the CLI promotes them.
```

`Succeeded` is true when `Errors` is empty (warnings ignored). Diagnostics carry a `Unit_Index` into the compilation set so the build can print the right filename/source.

## Environment (scopes)

The environment is a **scope stack** (innermost first on lookup). Entity kinds today:

| Kind | Bound by | Looked up for |
| --- | --- | --- |
| Local | Block `declare` | Expression / `:=` LHS |
| Parameter | Subroutine header | Expression / `:=` LHS (assigned on entry) |
| Module | `using M;` (unit-leading or block) | Call module prefix |
| Subroutine | Unit procedure list | Same-unit call resolve |

### Using visibility

| Rule | Behavior |
| --- | --- |
| Unit-leading `using` | Visible for the whole unit (all procedures / program body) |
| Block `using` | Visible for the rest of that block (inward); not visible after `end` |
| No shadowing | Nested `using M;` when `M` is already visible → parser `Name_Clash` (`LV00011`) |
| Same block duplicate | Duplicate `using M;` → `LV00011` |
| Sibling blocks | Each may `using M;` — allowed |
| Self-using | Using name equals unit name → `LV00011` |
| `using … as …` | Reserved; not parsed |

Call sites use the environment **at the call**, not only unit-leading usings. Lexeme `import` is an ordinary identifier (parser `Unexpected_Token` if used as a using).

### Name resolution for variables

- Identifier expressions and `:=` LHS resolve through `Lookup_Variable` (locals + parameters).
- Unknown / out-of-scope name → `Unresolved_Name` (`LV00031`).
- Shadowing of locals/parameters is rejected at parse (`LV00011`).

## Call-target resolve

Callees remain **qualified**: `MODULE.SUBROUTINE(…)`. Resolve runs here (not in IR). Actual expressions are typed **before** resolve so overloads can be selected by parameter types.

### Overload by parameter types

Multiple procedures may share a **name** in one module when their **ordered parameter type sequences** differ. **Return type is not part of the signature.** Identical name + identical param types → parser `Name_Clash` (`LV00011`).

Resolution:

1. Split `MODULE.SUBROUTINE`.
2. Same-unit prefix **or** module in scope via `using` (mark that using **used**); else `Call_Without_Using` (`LV00017`).
3. Collect same-name procedures (cross-module: only `export`ed).
4. Keep candidates where arity matches **and** each actual is assignable to the corresponding formal (`Typecheck.Is_Assignable`).
5. **0** fully matching candidates → `Unresolved_Call` (`LV00014`); **1** → use it; **≥2** → `Ambiguous_Call` (`LV00033`).
6. If cross-module same-name procedures exist but none are exported → `Not_Exported` (`LV00018`).

Bare integer literals (`1`) are `Integer_Literal` and match by range, so `Sink(integer)` vs `Sink(integer<8>)` is ambiguous for `Sink(1)`. A trailing signedness/size suffix pins a concrete integer type (`1s8` → `integer<8>`, `1s32` / `1s` → `integer`) and removes that ambiguity — see [literals.md](literals.md).

Same-unit calls do **not** mark usings used. Unqualified calls stay illegal at parse.

| Situation | Code |
| --- | --- |
| Module prefix is neither the current unit nor in scope via `using` | `Call_Without_Using` (`LV00017`) |
| No matching overload (wrong arity/types) or procedure missing | `Unresolved_Call` (`LV00014`) |
| Two or more overloads match equally | `Ambiguous_Call` (`LV00033`) |
| Cross-module: same name exists but none exported | `Not_Exported` (`LV00018`) |

Samples: [`samples/overload/Overload.love`](../samples/overload/Overload.love) (same-module), [`OverloadCaller.love`](../samples/overload/OverloadCaller.love) + [`OverloadLib.love`](../samples/overload/OverloadLib.love) (cross-module).

## Definite assignment

Straight-line + nested blocks (a nested `begin`…`end;` always runs). One assigned bit per variable slot.

| Rule | Decision |
| --- | --- |
| Parameters | **Assigned** at procedure entry |
| Locals | Start **unassigned**; `LHS := …` marks that name assigned afterward |
| Read of unassigned local | `Use_Before_Assignment` (`LV00026`) — RHS, call actual, … |
| Nested block | Assignments inside remain assigned after the nested `end` (block always executes) |
| Path-sensitive `if` / loops | Not in this slice; analysis is structured so those constructs plug in later (see roadmap step 6) |

## Types (`Lovelace_Type`)

Syntactic `Types.Type_Expression` is lifted into a semantic `Lovelace_Type` with classes: `Unknown`, `Unit`, `Boolean`, `Integer` (signedness + width), `Float` (width), `Integer_Literal` (value known).

`Unknown` is used after earlier errors and is assignable both ways to limit cascades.

### Assignability (this slice)

`:=` and call actuals vs formals use the **same** `Typecheck.Is_Assignable` / `Check_Assignable` API. Mismatch → `Type_Mismatch` (`LV00027`).

| Target | Source | Result |
| --- | --- | --- |
| `boolean` | `boolean` / `true` / `false` | OK |
| `boolean` | integer / integer literal | Error |
| integer width *W* (signed/unsigned) | same signedness + same width integer variable | OK |
| integer width *W* (≤32) | integer literal in range of *W* | OK (literal fits) |
| unsigned integer | negative literal | Error |
| `integer<64>` / `unsigned integer<64>` | integer literal | Error (this slice) |
| float width *W* | float same width | OK |
| float | integer / boolean / literal | Error |
| integer | float / boolean | Error |
| any | `Unknown` (or target `Unknown`) | OK (cascade suppression) |

No implicit narrowing between distinct integer widths. No boolean ↔ integer. Explicit casts are out of scope for this slice (roadmap later steps).

Bare integer literals are typed as `Integer_Literal_Class` until checked against a target. Literals with a signedness/size suffix are typed as a concrete `Integer_Class` (and must fit that width).

## Unused analysis (warnings)

Runs after resolve / DA / types on a successful-enough walk. Codes are warnings (`LV00028` / `LV00029` / `LV00032`); see [diagnostics.md](diagnostics.md) for CLI promote/suppress.

| Code | When |
| --- | --- |
| `Unused_Variable` (`LV00028`) | Local **never read** (assignment alone is not a use) |
| `Unused_Assignment` (`LV00029`) | A specific `:=` whose value is never read before overwrite/end — only if the local is read at least once elsewhere |
| `Unused_Using` (`LV00032`) | A `using M;` (unit-leading or block) was never required for call resolve — `Lookup_Module` never found that binding for a call |

A using is marked **used** when call resolve successfully finds that module in scope (even if the procedure is later missing / not exported). Same-unit calls do not use usings. Nested block usings are checked at block end; remaining unit-level usings after all subroutines.

**Priority:** never-read local → only `Unused_Variable` (do not also emit Unused_Assignment for that name). Parameters never get `Unused_Variable`. Unused_Using is independent of Unused_Variable.

## Out of scope (here)

- Operators, `if`, loops, expression forms beyond literal / identifier
- `using … as …`, unqualified use after using
- Module-level variables, initializers on `declare`
- Explicit casts / full numeric cast matrix

Those extend this API rather than inventing parallel checkers (see roadmap 1.002 / 2.001).
