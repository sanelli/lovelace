---
name: Source comments braces
overview: "Implement roadmap 1.002 macro step 1 — Lovelace `{ … }` block comments (non-nesting); ignored like whitespace; unterminated/stray/nested are tokenizer errors."
todos:
  - id: "1"
    content: "1. Create GitHub issue with gh issue create (source comments / roadmap 1.002 macro step 1); reuse if equivalent open issue exists; record <n>."
    status: completed
  - id: "2"
    content: "2. Sync main, then gh issue develop <n> --name feature/<n>-source-comments --checkout --base main. Verify with gh issue develop --list <n>."
    status: completed
  - id: "3"
    content: "3. Save this plan as .cursor/plans/<nnn>-source-comments.plan.md with #<n> in the body (rename from 035 if issue number differs)."
    status: completed
  - id: "4"
    content: "4. Tokenizer errors: Unterminated_Comment + Nested_Comment + Stray_Comment_Closer; LV codes + Diagnostics reporting + diagnostics.md; gnatformat."
    status: pending
  - id: "5"
    content: "5. Tokenizer: after whitespace, scan `{`…`}` comments (discard; no token); reject nest/unterminated/stray; AUnit tokenizer tests; gnatformat."
    status: pending
  - id: "6"
    content: "6. Docs: token-grammar, tokenizer.md; lock comment rules on roadmap 1.002 step 1; update augusta.md; gnatformat N/A."
    status: pending
  - id: "7"
    content: "7. Sample: TEMPORARY `{ … }` on augusta.std.io wasi print; optional tiny samples/comments sample; docs/samples.md if needed."
    status: pending
  - id: "8"
    content: "8. Parser/build smoke: existing units with embedded comments still parse/build; AUnit as needed."
    status: pending
  - id: "9"
    content: "9. Run all existing tests (nested AUnit crates / scripts/run-tests.ps1)."
    status: pending
  - id: "10"
    content: "10. Push (proxy env cleared) and open a PR with gh pr create."
    status: pending
isProject: false
---

# Source comments `{ … }` (roadmap 1.002 macro step 1)

#35 — [Compiler: source comments { … } (roadmap 1.002 macro step 1)](https://github.com/sanelli/lovelace/issues/35)

Branch: `feature/35-source-comments` (linked to #35; created from `main` via `gh issue develop`).

Plan file: [`.cursor/plans/035-source-comments.plan.md`](035-source-comments.plan.md).

Roadmap: [docs/roadmap/1.002-roadmap-replace-synthesized-print.md](../../docs/roadmap/1.002-roadmap-replace-synthesized-print.md) § Macro step 1.

**How to execute:** one numbered step per invocation (or an explicit consecutive range). Do not skip the envelope (1–3) or the closing tests/PR. After each Ada edit step, run `alr exec -- gnatformat` on touched files and build/run the relevant test crate before moving on.

## Locked decisions

- **Form:** Ada-style **block** comments delimited by **`{`** and **`}`** (not `(* *)`, not `--`, not `//`).
- **No nesting:** while inside a comment, a literal `{` is a **tokenizer error** (`Nested_Comment`). Comment text may contain `}` only as the terminator; any `{` before that closer is nesting and fails.
- **Unterminated:** `{` with no matching `}` before EOF → **tokenizer error** (`Unterminated_Comment`), same recovery spirit as `Unterminated_String_Literal`.
- **Stray closer:** `}` outside a comment → **tokenizer error** (`Stray_Comment_Closer`).
- **Semantics:** comments are **not tokens**. Skip them like whitespace in [`Tokenize_Core`](../../compiler/src/lovelace-compiler-tokenizer.adb) so the parser needs **no** grammar changes for comments themselves.
- **Strings win:** `"…"` is scanned as `String_Literal`; `{` / `}` inside a string are **not** comment delimiters.
- **`{` / `}` are not punctuation** in this language slice (they are reserved as comment delimiters only). Do not add them to `Punctuation_Subtype`.
- **Line/column:** advancing through comment body must update line/column the same way as other multi-byte/multi-line spans (`Advance_Bytes`).
- **Out of scope:** line comments; nested comments; doc-comment AST; roadmap 1.002 steps 2+ (literals, boolean, locals, …); LIR/backend changes.

Example:

```love
module augusta.std.io;

#if flavor = "wasi"

{ TEMPORARY: print is native("wasi", "native-print-integer") until
  Lovelace can format digits in-language (roadmap 1.002). }
export native("wasi", "native-print-integer") procedure print(value : integer);

#end
end.
```

Errors (illustrative):

| Source | Error |
| --- | --- |
| `{ never closed` | `Unterminated_Comment` |
| `}` alone | `Stray_Comment_Closer` |
| `{ outer { nest } }` | `Nested_Comment` at inner `{` |

## Architecture

```mermaid
flowchart TD
  loop[Tokenize_Core loop]
  ws[Skip whitespace]
  brace{"Next byte is `{` or `}`?"}
  openComment[Scan comment to `}`]
  stray[Report Stray_Comment_Closer]
  nest[Report Nested_Comment]
  unterminated[Report Unterminated_Comment]
  longest[Longest_Scan_Match tokens]
  loop --> ws --> brace
  brace -->|"{"| openComment
  brace -->|"}"| stray
  brace -->|else| longest
  openComment -->|inner "{"| nest
  openComment -->|EOF| unterminated
  openComment -->|"}"| loop
  longest --> loop
```

## Steps

### 1–3. Envelope

**Done:** issue #35, branch `feature/35-source-comments`, this plan file.

### 4. Diagnostics

Files:

- [`compiler/src/lovelace-compiler-tokenizer.ads`](../../compiler/src/lovelace-compiler-tokenizer.ads) — extend `Tokenizer_Error_Code`
- [`compiler/src/lovelace-compiler-error_codes.ads`](../../compiler/src/lovelace-compiler-error_codes.ads) / reporting — map to **`LV00022`**, **`LV00023`**, **`LV00024`** (next free after `LV00021`)
- [`docs/diagnostics.md`](../../docs/diagnostics.md)

Proposed codes:

| Code | Ada enum | Meaning |
| --- | --- | --- |
| `LV00022` | `Unterminated_Comment` | `{` without closing `}` |
| `LV00023` | `Nested_Comment` | `{` inside an open comment |
| `LV00024` | `Stray_Comment_Closer` | `}` outside a comment |

Wire printer text consistently with `Unterminated_String_Literal` / `LV00013`.

### 5. Tokenizer scan

File: [`compiler/src/lovelace-compiler-tokenizer.adb`](../../compiler/src/lovelace-compiler-tokenizer.adb)

In `Tokenize_Core`, after skipping whitespace and **before** `Longest_Scan_Match`:

1. If current scalar/byte is `}` → `Report_Stray_Comment_Closer`, advance one scalar, continue (collect errors; discard tokens at end as today).
2. If current is `{` → enter comment mode:
   - Advance past `{`
   - Scan until `}`: on `{` → `Nested_Comment` and stop/recover; on EOF → `Unterminated_Comment`; on `}` → exit comment mode (do not emit a token)
3. Else existing longest-match path (string literals still own interior braces)

Do **not** register a comment regex scan class that emits tokens. Hand-scan keeps nest/unterminated diagnostics precise (same pattern as unterminated `"`).

AUnit in [`compiler/tests`](../../compiler/tests):

- Comments between keywords/idents/punct: token stream identical to comment-free source
- Multi-line comments; comment adjacent to tokens (`end{c};` / `end{c};` spacing variants)
- `{` inside `"…"` does not start a comment
- Nested / unterminated / stray → `Ok = False` with expected codes
- Empty `{}` is a valid empty comment (skipped)

### 6. Docs + roadmap status

- [`docs/token-grammar.md`](../../docs/token-grammar.md) — `comment = "{" , { comment_character } , "}" ;` with note: no nesting; not emitted
- [`docs/tokenizer.md`](../../docs/tokenizer.md) — whitespace section sibling: comments ignored; error table
- [`docs/roadmap/1.002-roadmap-replace-synthesized-print.md`](../../docs/roadmap/1.002-roadmap-replace-synthesized-print.md) — lock `{`/`}` + non-nesting; mark macro step 1 status with #35
- [`docs/augusta.md`](../../docs/augusta.md) — drop “comments not in the language yet” once sample uses them

### 7. Sample

- Add TEMPORARY `{ … }` above wasi `print` in [`augusta/augusta.std.io.love`](../../augusta/augusta.std.io.love)
- Optional: `samples/comments/…` only if useful beyond Augusta; update [`docs/samples.md`](../../docs/samples.md) if added

### 8. Parser / build smoke

- No parser grammar change required
- Ensure `lovelace build` on HelloPrint / Augusta still works with the new comment in `augusta.std.io.love`
- Add a small parser fixture that embeds comments in a module/program if tokenizer-only coverage is insufficient

### 9. Full tests

```bash
# e.g.
alr -C compiler/tests run
AUGUSTA_HOME="$PWD/augusta" alr -C lovelace/integration_tests run
# or pwsh scripts/run-tests.ps1
```

### 10. Push / PR

Clear proxy env, `git push -u origin HEAD`, `gh pr create` closing #35, referencing roadmap 1.002 step 1.

## Non-goals (reminders)

- Do not implement `0b`/`0o`/`0x`, boolean, `:=`, or other 1.002 steps in this PR
- Do not treat `{`/`}` as future block or attribute syntax in this slice
