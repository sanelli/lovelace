# TextMate grammars

Shared **TextMate** syntax grammars for Lovelace (`.love`) and LIR text (`.tlir`).

Editors and IDE plugins under [`../vscode/`](../vscode/) and [`../jetbrains/`](../jetbrains/) should reuse these grammars for syntax coloring rather than maintaining separate highlighter definitions.

| File | Language | `scopeName` | Extensions |
| --- | --- | --- | --- |
| [`lovelace.tmLanguage.json`](lovelace.tmLanguage.json) | Lovelace | `source.lovelace` | `.love` |
| [`tlir.tmLanguage.json`](tlir.tmLanguage.json) | Lovelace LIR (text) | `source.lovelace.tlir` | `.tlir` |

Binary `.lir` is out of scope for TextMate (see [1.005](../../docs/roadmap/1.005-roadmap-ide-plugins-build-run.md) dump / binary viewer).

Folder name is lowercase `textmate/` for path consistency; the format is TextMate.

## Keep in sync

**Every new language feature or `.tlir` surface change must update these grammars in the same work.** Do not land tokenizer / parser / TLIR syntax changes without matching TextMate coverage. Roadmap: [1.002](../../docs/roadmap/1.002-roadmap-replace-synthesized-print.md) macro step 8; project documentation rule.

When you add or change surface syntax, update the matching grammar in the same PR:

| Change | Update |
| --- | --- |
| New `.love` keyword, directive, punctuation, or literal form | [`lovelace.tmLanguage.json`](lovelace.tmLanguage.json) keyword / directive / punctuation / numeric rules (and [token-grammar.md](../../docs/token-grammar.md)) |
| New `@attribute` name with dedicated coloring | `attribute` rule in [`lovelace.tmLanguage.json`](lovelace.tmLanguage.json) |
| New TLIR structural head, instruction opcode, type token, or flag name | closed lists in [`tlir.tmLanguage.json`](tlir.tmLanguage.json) (and [lir-text.md](../../docs/lir-text.md)) |
| New TLIR string escape | `string` escape pattern in [`tlir.tmLanguage.json`](tlir.tmLanguage.json) |

Do **not** keyword-color future language words (`if` / `mod` / `and` / …) until the compiler tokenizer accepts them.

## Fixtures

Smoke snippets (highlighting only; not a compiler test suite):

| Path | Covers |
| --- | --- |
| [`fixtures/love/surface.love`](fixtures/love/surface.love) | Comments, directives, `@version` / `@intrinsic` / `@native`, literals, `declare` / `:=` / `using`, boolean |
| [`fixtures/love/emoji.love`](fixtures/love/emoji.love) | Emoji / Unicode identifiers |
| [`fixtures/tlir/empty.tlir`](fixtures/tlir/empty.tlir) | Empty-module writer golden |
| [`fixtures/tlir/surface.tlir`](fixtures/tlir/surface.tlir) | `index`, flags, locals, all five opcodes |
| [`fixtures/tlir/escapes.tlir`](fixtures/tlir/escapes.tlir) | Writer string escapes |

## Smoke-test in VS Code

Until the [1.005](../../docs/roadmap/1.005-roadmap-ide-plugins-build-run.md) extension ships, load a grammar manually:

1. Install a “TextMate Languages” / raw grammar preview extension, **or** point a minimal `package.json` `contributes.grammars` entry at these JSON files.
2. Open a fixture (or any `.love` / `.tlir` file) with the grammar applied.
3. Use **Developer: Inspect Editor Tokens and Scopes** on keywords, comments, `:=`, `@intrinsic`, `(module`, `i32.const`, and escaped strings.

Validate JSON anytime with:

```bash
python3 -m json.tool ide/textmate/lovelace.tmLanguage.json > /dev/null
python3 -m json.tool ide/textmate/tlir.tmLanguage.json > /dev/null
```
