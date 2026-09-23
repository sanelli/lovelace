# Source locations (`Lovelace.Common.Source`)

Crate `lovelace_common` owns UTF-8 source positions and optional shared filenames used by the compiler frontend and by in-memory LIR origins.

| Type / API | Role |
| --- | --- |
| `Source_Position` | 1-based `Byte_Index`, `Line`, and `Column` (Unicode scalars on the line; tab is one column) |
| `Source_Span` | Inclusive `First` .. `Last` positions |
| `Shared_Filename` | Refcounted immutable UTF-8 path or label (`Controlled`) |
| `Filename_Option` | Optional `Shared_Filename` (`Present` discriminant) |
| `Absent_Filename` / `From_Utf_8` / `Some_Filename` | Construct absent or present filenames |
| `To_Utf_8` | UTF-8 path bytes from a holder or option (empty when absent) |
| `Same_Storage` | True when two holders (or options) share one block |

The tokenizer and parser attach spans and optional filenames to tokens, errors, and AST nodes. The [IR Generator](ir-generator.md) copies those origins onto LIR modules and subroutines. LIR codecs persist origins in `.lir` / `.tlir` while keeping format version **1.0**; see [lir.md](lir.md), [lir-binary.md](lir-binary.md), and [lir-text.md](lir-text.md).

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). Usage from the lexer: [tokenizer.md](tokenizer.md).
