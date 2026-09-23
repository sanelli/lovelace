# Compiler diagnostics

User-facing compiler messages use stable codes of the form **`LV` + five zero-padded digits** (for example `LV00009`). Codes live in `Lovelace.Compiler.Error_Codes`; the printer is `Lovelace.Compiler.Diagnostics`.

Host **internal** failures (`Lovelace.Common.Internal_Error` / `Result`) are not this format — see the result-and-internal-errors rule. CLI usage mistakes (unknown flags, missing `.love`, bad `--output-format`) print a plain `[err]` block **without** an `LV#####` line.

CLI overview: [cli.md](cli.md).

## Located format

Located diagnostics are written to **stderr** as:

```text
[err] filename:{row},{column}
{line of source containing the error}
{caret line pointing at the span}
[LVxxxxx] {description}
```

Rules:

- `{row}` and `{column}` come from the span’s `First` position (1-based).
- The source line is taken from the UTF-8 buffer using that span.
- The caret line pads to `Column`, then uses `^` for a single column or repeated `^` across `First` … `Last` when the span covers more than one column.
- Colour (when enabled): `[err]` and the `[LVxxxxx]` line are red; the printer itself emits no ANSI escapes.

Example (`LV00009`):

```text
[err] Hello.love:1,9
program Hello; begin end.
        ^^^^^
[LV00009] program name does not match file name
```

Multiple errors: each block is printed in order; the process exits non-zero if any error occurred.

## Unlocated / CLI shape

When there is no useful source span (or for CLI usage errors):

```text
[err] {context}


{description}
```

`{context}` is a short label such as `command line` or `build`. There is **no** `[LVxxxxx]` line for pure CLI errors.

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
| `LV00009` | Program_Name_Filename_Mismatch | Build (program id vs `.love` stem) |
| `LV00010` | Source_File_Io | Build (missing or unreadable source) |

Stage-local enums (tokenizer, parser, …) map to these labels at report time via `Lovelace.Compiler.Reporting`.

## Warnings (not yet in this slice)

The diagnostics **rule** reserves warnings-as-errors, suppressions, and style warnings for later. This slice emits **errors only**.

## Origins on LIR

When a `.lir` is loaded for the backend, module/subroutine origins (filename + row/column) may be present so later diagnostics can point at the original `.love` spans. Format version remains **1.0**; see [lir.md](lir.md) and [lir-binary.md](lir-binary.md).
