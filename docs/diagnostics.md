# Compiler diagnostics

User-facing compiler messages use stable codes of the form **`LV` + five zero-padded digits** (for example `LV00009`). Codes live in `Lovelace.Compiler.Error_Codes`; the printer is `Lovelace.Compiler.Diagnostics`.

Host **internal** failures (`Lovelace.Common.Internal_Error` / `Result`) are not this format — see the result-and-internal-errors rule. CLI usage mistakes (unknown flags, missing `.love`, bad `--output-format`) print a plain `[err]` block **without** an `LV#####` line.

CLI overview: [cli.md](cli.md). Semantic rules (scopes, DA, types, resolve, unused): [semantics.md](semantics.md).

## Located format

Located diagnostics are written to **stderr** as:

```text
[err] filename:{row},{column}
{line of source containing the error}
{caret line pointing at the span}
[LVxxxxx] {description}
```

Warnings use `[warning]` instead of `[err]` on the first line (and on the `[LVxxxxx]` line styling when colour is on).

Rules:

- `{row}` and `{column}` come from the span’s `First` position (1-based).
- The source line is taken from the UTF-8 buffer using that span.
- The caret line pads to `Column`, then uses `^` for a single column or repeated `^` across `First` … `Last` when the span covers more than one column.
- Colour (when enabled): `[err]` / error `[LVxxxxx]` are red; `[warning]` lines use the warning style; the printer itself emits no ANSI escapes beyond those markers.

Example (`LV00009` for a program; modules use the same code with a `module identifier …` description):

```text
[err] Hello.love:1,9
program Hello; begin end.
        ^^^^^
[LV00009] program identifier 'Hello' does not match file stem 'Other'
```

Multiple diagnostics: each block is printed in order. The process exits non-zero if any remaining **error** occurred (including warnings promoted by `--warning-as-errors`). Warnings alone → exit 0.

## Unlocated / CLI shape

When there is no useful source span (or for CLI usage errors):

```text
[err] {context}


{description}
```

`{context}` is a short label such as `command line` or `compile`. There is **no** `[LVxxxxx]` line for pure CLI errors (except when a stable code is emitted for invalid warning suppression — see `LV00030`).

## Severity

| Severity | Role |
| --- | --- |
| `Error` | Fails the build (non-zero exit) |
| `Warning` | Printed by default; does not fail the build unless promoted |

| CLI flag | Behavior |
| --- | --- |
| `--warning-as-errors` | Every warning is promoted to error (counts toward failure; printed as errors) |
| `--no-warnings LV00028,LV00029` | Comma-separated list (one argv value). Those **warning** codes are suppressed (not printed; not promoted). Requires ≥1 id |
| Invalid `--no-warnings` entry | Unknown code **or** code that is not a warning → hard error `Invalid_Warning_Suppression` (`LV00030`) |

## Code table

| Code | Kind | Typical stage |
| --- | --- | --- |
| `LV00001` | Internal_Error | Any (compiler bug / impossible state) |
| `LV00002` | Unrecognized_Symbol | Tokenizer |
| `LV00003` | Invalid_Utf_8 | Tokenizer |
| `LV00004` | Unexpected_End_Of_Input | Parser |
| `LV00005` | Unexpected_Token | Parser |
| `LV00006` | Unexpected_Trailing | Parser |
| `LV00007` | Unsupported_Type | Backend |
| `LV00008` | Invalid_Module | Backend / LIR validate surfaced to the user |
| `LV00009` | Program_Name_Filename_Mismatch | Compile (program/module id vs `.love` stem) |
| `LV00010` | Source_File_Io | Compile (missing or unreadable source) |
| `LV00011` | Name_Clash | Parser (duplicate or conflicting procedure/parameter/using/local name; self-using; using shadow) |
| `LV00012` | Invalid_Flavor_Condition | Parser (`#if`/`#elsif` flavor string not wasi/native/web) |
| `LV00013` | Unterminated_String_Literal | Tokenizer (opening `"` without a matching closer) |
| `LV00014` | Unresolved_Call | Semantics (no matching overload / missing procedure) |
| `LV00015` | Invalid_Arguments | Historical; call arity mismatches are reported as `Unresolved_Call` when no overload matches |
| `LV00016` | Unknown_Module | Unit graph (using name has no candidate `.love` on search roots) |
| `LV00017` | Call_Without_Using | Semantics (callee module prefix not brought in by a `using` in scope) |
| `LV00018` | Not_Exported | Semantics (used procedure exists but lacks `Export_Flag`) |
| `LV00019` | Circular_Import | Unit graph (using cycle among compilation units; enum name is historical) |
| `LV00020` | Ambiguous_Module_Path | Unit graph (two or more distinct `.love` files match one using) |
| `LV00021` | Unknown_Native_Binding | *Retired* — old `native(target, key)` closed wasi set; no longer emitted |
| `LV00022` | Unterminated_Comment | Tokenizer (opening `{` without a matching `}`) |
| `LV00023` | Nested_Comment | Tokenizer (`{` inside an open `{` … `}` comment) |
| `LV00024` | Stray_Comment_Closer | Tokenizer (`}` outside a comment) |
| `LV00025` | Unknown_Intrinsic | IR Generator (`@intrinsic` signature not in the closed intrinsic table) |
| `LV00026` | Use_Before_Assignment | Semantics (read of a local that is not definitely assigned) |
| `LV00027` | Type_Mismatch | Semantics (assignment or call actual not assignable) |
| `LV00028` | Unused_Variable | Warning: local never read (assignment alone is not a use) |
| `LV00029` | Unused_Assignment | Warning: store whose value is never read before overwrite/end (only when the local is read at least once elsewhere) |
| `LV00030` | Invalid_Warning_Suppression | CLI/compile: `--no-warnings` entry unknown or not a warning |
| `LV00031` | Unresolved_Name | Semantics (identifier does not name a visible local or parameter) |
| `LV00032` | Unused_Using | Warning: a `using M;` was never required for call resolve |
| `LV00033` | Ambiguous_Call | Semantics (two or more overloads match a call equally) |
| `LV00034` | Invalid_Module_Version | Parser / unit graph: `@version("…")` in a `.love` file or `.loveversion` is not `MAJOR.MINOR.BUILD[-preview-name[.preview-number]]` (`.loveversion` that is unreadable reports `LV00010`) |

Stage-local enums (tokenizer, parser, semantics, IR generator, unit graph, …) map to these labels at report time via `Lovelace.Compiler.Reporting` (unit-graph failures also expose `Unit_Graph.Surface_Error_Code`).

## Warnings

Warning codes today: `Unused_Variable` (`LV00028`), `Unused_Assignment` (`LV00029`), `Unused_Using` (`LV00032`).

**Priority:** if a local is never read → only **Unused_Variable** (even if assigned). If a local is read at least once → emit **Unused_Assignment** for any `:=` whose value is not read before overwrite/end. Parameters never get Unused_Variable. Unused_Using is independent. Full semantic rules: [semantics.md](semantics.md).

See CLI flags under Severity above.

## Origins on LIR

When a `.lir` is loaded for the backend, module/subroutine origins (filename + row/column) may be present so later diagnostics can point at the original `.love` spans. Format version remains **1.0**; see [lir.md](lir.md) and [lir-binary.md](lir-binary.md).
