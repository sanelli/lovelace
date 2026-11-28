# TextMate grammars

Shared **TextMate bundles** for Lovelace (`.love`) and LIR text (`.tlir`), in the same layout JetBrains / TextMate expect (see e.g. `ada.tmbundle`: `info.plist` + `Syntaxes/`).

Editors and IDE plugins under [`../vscode/`](../vscode/) and [`../jetbrains/`](../jetbrains/) should reuse these bundles for syntax coloring rather than maintaining separate highlighter definitions.

| Bundle | Language | `scopeName` | Extensions |
| --- | --- | --- | --- |
| [`Lovelace.tmbundle/`](Lovelace.tmbundle/) | Lovelace | `source.lovelace` | `.love` |
| [`TLIR.tmbundle/`](TLIR.tmbundle/) | Lovelace LIR (text) | `source.lovelace.tlir` | `.tlir` |

Grammar sources:

- [`Lovelace.tmbundle/Syntaxes/Lovelace.tmLanguage.json`](Lovelace.tmbundle/Syntaxes/Lovelace.tmLanguage.json)
- [`TLIR.tmbundle/Syntaxes/TLIR.tmLanguage.json`](TLIR.tmbundle/Syntaxes/TLIR.tmLanguage.json)

Binary `.lir` is out of scope for TextMate (see [1.005](../../docs/roadmap/1.005-roadmap-ide-plugins-build-run.md) dump / binary viewer).

Folder name is lowercase `textmate/` for path consistency; each language lives in its own `*.tmbundle`.

## Import into Rider / IntelliJ

Rider’s **TextMate Bundles** UI expects a real bundle directory (with `info.plist` and `Syntaxes/`), **not** the parent `ide/textmate/` folder. Importing `ide/textmate` fails with “Cannot read the following bundle”.

1. Settings → **Editor → TextMate Bundles**
2. Click **+** and select **`ide/textmate/Lovelace.tmbundle`**
3. Click **+** again and select **`ide/textmate/TLIR.tmbundle`**
4. Open a fixture (or any `.love` / `.tlir` file) and confirm highlighting

## Keep in sync

**Every new language feature or `.tlir` surface change must update these grammars in the same work.** Do not land tokenizer / parser / TLIR syntax changes without matching TextMate coverage. Roadmap: [1.002](../../docs/roadmap/1.002-roadmap-replace-synthesized-print.md) macro step 8; project documentation rule.

When you add or change surface syntax, update the matching grammar in the same PR:

| Change | Update |
| --- | --- |
| New `.love` keyword, directive, punctuation, or literal form | [`Lovelace.tmLanguage.json`](Lovelace.tmbundle/Syntaxes/Lovelace.tmLanguage.json) (and [token-grammar.md](../../docs/token-grammar.md)) |
| New `@attribute` name with dedicated coloring | `attribute` rule in [`Lovelace.tmLanguage.json`](Lovelace.tmbundle/Syntaxes/Lovelace.tmLanguage.json) |
| New TLIR structural head, instruction opcode, type token, or flag name | closed lists in [`TLIR.tmLanguage.json`](TLIR.tmbundle/Syntaxes/TLIR.tmLanguage.json) (and [lir-text.md](../../docs/lir-text.md)) |
| New TLIR string escape | `string` escape pattern in [`TLIR.tmLanguage.json`](TLIR.tmbundle/Syntaxes/TLIR.tmLanguage.json) |

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

1. Point a minimal `package.json` `contributes.grammars` entry at the JSON files under each bundle’s `Syntaxes/`.
2. Open a fixture (or any `.love` / `.tlir` file) with the grammar applied.
3. Use **Developer: Inspect Editor Tokens and Scopes** on keywords, comments, `:=`, `@intrinsic`, `(module`, `i32.const`, and escaped strings.

Validate JSON anytime with:

```bash
python3 -m json.tool ide/textmate/Lovelace.tmbundle/Syntaxes/Lovelace.tmLanguage.json > /dev/null
python3 -m json.tool ide/textmate/TLIR.tmbundle/Syntaxes/TLIR.tmLanguage.json > /dev/null
```
