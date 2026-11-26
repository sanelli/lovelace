# Source locations (`Lovelace.Common.Source`)

Crate `lovelace_common` owns UTF-8 source positions and optional shared filenames used by the compiler frontend and by in-memory LIR origins.

| Type / API | Role |
| --- | --- |
| `Source_Position` | 1-based `Byte_Index`, `Line`, and `Column` (Unicode scalars on the line; tab is one column) |
| `Source_Span` | Inclusive `First` .. `Last` positions |
| `Shared_Filename` | Positive index into a **global** interned filename pool (UTF-8 path or label) |
| `Filename_Option` | Optional `Shared_Filename` (`Present` discriminant) |
| `Absent_Filename` / `From_Utf_8` / `Some_Filename` | Construct absent or present filenames (`From_Utf_8` interns) |
| `To_Utf_8` | UTF-8 path bytes from a holder or option (empty when absent) |
| `Same_Storage` | True when two holders (or options) share the **same pool index** |
| `Clear_Filename_Pool` | Drop every interned string; invalidates existing holders |

## Filename pool

- **Ownership:** process-global table inside `Lovelace.Common.Source` (protected object — thread-safe for future parallel tokenize/parse).
- **Interning:** equal UTF-8 text yields one index; holders are cheap `Positive` values with no per-assign string copy or controlled finalize (gnatcov-safe).
- **Lifetime:** `Lovelace.Main.Compile.Run` clears the pool at the **start** and **end** of each compile command (including on exception). Do not keep `Shared_Filename` / present `Filename_Option` values across that boundary.

The tokenizer and parser attach spans and optional filenames to tokens, errors, and AST nodes. The [IR Generator](ir-generator.md) copies those origins onto LIR modules and subroutines. LIR codecs persist origins in `.lir` / `.tlir` while keeping format version **1.0**; see [lir.md](lir.md), [lir-binary.md](lir-binary.md), and [lir-text.md](lir-text.md).

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). Usage from the lexer: [tokenizer.md](tokenizer.md).
