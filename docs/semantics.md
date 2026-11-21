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

Callees remain **qualified**: `MODULE.SUBROUTINE(…)`. Resolve runs here (not in IR).

| Situation | Code |
| --- | --- |
| Module prefix is neither the current unit nor in scope via `using` | `Call_Without_Using` (`LV00017`) |
| Module in scope (or same-unit prefix), procedure missing | `Unresolved_Call` (`LV00014`) |
| Cross-module procedure exists but lacks `export` | `Not_Exported` (`LV00018`) |
| Arity differs from formals | `Invalid_Arguments` (`LV00015`) |

Same-unit calls still require the subroutine to exist. Unqualified calls stay illegal at parse.

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

Integer literals are typed as `Integer_Literal_Class` until checked against a target; they are not a free-standing “default integer” expression type beyond that check.

## Unused analysis (warnings)

Runs after resolve / DA / types on a successful-enough walk. Codes are warnings (`LV00028` / `LV00029`); see [diagnostics.md](diagnostics.md) for CLI promote/suppress.

| Code | When |
| --- | --- |
| `Unused_Variable` (`LV00028`) | Local **never read** (assignment alone is not a use) |
| `Unused_Assignment` (`LV00029`) | A specific `:=` whose value is never read before overwrite/end — only if the local is read at least once elsewhere |

**Priority:** never-read local → only `Unused_Variable` (do not also emit Unused_Assignment for that name). Parameters never get `Unused_Variable`.

## Out of scope (here)

- Operators, `if`, loops, expression forms beyond literal / identifier
- `using … as …`, unqualified use after using
- Module-level variables, initializers on `declare`
- Explicit casts / full numeric cast matrix

Those extend this API rather than inventing parallel checkers (see roadmap 1.002 / 2.001).
