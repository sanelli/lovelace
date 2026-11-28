# IDE support

Editor and IDE integrations for Lovelace (`.love`) and LIR (`.lir` / `.tlir`). Nothing here is an Alire host crate; plugins and grammars will live in these subfolders as they are implemented.

| Path | Role |
| --- | --- |
| [`lsp/`](lsp/) | Language Server Protocol for Lovelace and LIR |
| [`textmate/`](textmate/) | Shared TextMate **bundles** for `.love` / `.tlir` (`Lovelace.tmbundle`, `TLIR.tmbundle`; keep in sync with every language/TLIR change) |
| [`vscode/`](vscode/) | Visual Studio Code extension (LSP + TextMate + build/run/debug; optional WIT/WAT viewers) |
| [`jetbrains/`](jetbrains/) | JetBrains plugin (same goals; WebStorm is the primary target) |
