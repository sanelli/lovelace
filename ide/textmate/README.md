# TextMate grammars

Shared **TextMate** syntax grammars for Lovelace (`.love`) and LIR text (`.tlir`).

Editors and IDE plugins under [`../vscode/`](../vscode/) and [`../jetbrains/`](../jetbrains/) should reuse these grammars for syntax coloring rather than maintaining separate highlighter definitions.

## Keep in sync

**Every new language feature or `.tlir` surface change must update these grammars in the same work.** Do not land tokenizer / parser / TLIR syntax changes without matching TextMate coverage. Roadmap: [1.002](../../docs/roadmap/1.002-roadmap-replace-synthesized-print.md) macro step 8; project documentation rule.

Folder name is lowercase `textmate/` for path consistency; the format is TextMate.
