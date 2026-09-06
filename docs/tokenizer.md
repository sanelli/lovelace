# Compiler tokenizer

`Lovelace.Compiler.Tokenizer` turns UTF-8 source into a token sequence, or a list of located errors. It lives in crate `lovelace_compiler` and uses the host [regex engine](regex-engine.md) (`Compile` / `Match_Prefix`) for whitespace, identifiers, and punctuation.

This slice is keywords, identifiers, and two punctuation marks. There is no parser, no CLI wiring, and no `lovelace` executable dependency on `lovelace_compiler` yet.

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). The token grammar for this slice is in [token-grammar.md](token-grammar.md).

## API

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Source` | `Source_Position`, `Source_Span`, refcounted `Shared_Filename`, `Filename_Option` |
| `Lovelace.Compiler.Tokens` | `Token`, `Token_Sequence`, `Lexeme` |
| `Lovelace.Compiler.Tokenizer` | `Tokenize`, `Tokenize_Result`, `Tokenizer_Error` |

```ada
function Tokenize (Source_Text : String) return Tokenize_Result;
function Tokenize (Source_Text : String; Filename : String) return Tokenize_Result;
```

`Tokenize_Result` is tokens **or** errors, not both:

| `Ok` | Payload |
| --- | --- |
| `True` | `Tokens` — every recognized token; the source had no tokenizer errors |
| `False` | `Errors` — every collected error; recovered tokens are discarded |

Handle both discriminants (see the Result rule). Do not read `Tokens` when `Ok` is `False`, or `Errors` when `Ok` is `True`.

```ada
declare
   Result : constant Lovelace.Compiler.Tokenizer.Tokenize_Result :=
     Lovelace.Compiler.Tokenizer.Tokenize ("program begin end.");
begin
   case Result.Ok is
      when True =>
         null;  --  Result.Tokens
      when False =>
         null;  --  Result.Errors
   end case;
end;
```

Empty source and whitespace-only source succeed with an empty token sequence.

## Token kinds

| `Token_Kind` | Subtype | This slice |
| --- | --- | --- |
| `Keyword` | `Keyword_Subtype` | `program`, `begin`, `end` |
| `Identifier` | (none) | Names, including `@foo`, `café`, emoji |
| `Punctuation` | `Punctuation_Subtype` | `;` → `Semicolon`, `.` → `Full_Stop` |

Keywords are **case-sensitive**. `Program`, `BEGIN`, and `End` are identifiers.

The scanner matches a full identifier first, then classifies. `programmer` is one identifier, not `program` plus `mer`. `programbegin` is one identifier.

Lexeme text is not stored on the token. Recover it with `Lexeme (Source_Text, The_Token)`, which slices `Source_Text (First.Byte_Index .. Last.Byte_Index)`. `Last.Byte_Index` is the **last byte** of the last scalar (the span covers the full UTF-8 sequence).

`Source_Position` stores 1-based `Byte_Index`, `Line`, and `Column`. Column counts Unicode scalars on the line; tab is one column. LF, CR, and CRLF (one line break) update line and column.

## Whitespace

Any space between tokens is **ignored**: consumed, not emitted, not attached to the previous or next token. That includes ASCII space, tab, LF, CR, FF, Unicode space separators, and line terminators (NBSP, NEL, ideographic space, and similar). Adjacent tokens with no space (`end;`) are valid.

String literals are not tokenized yet. When they exist, spaces **inside** a string will be kept; that path does not exist in this slice.

## Identifiers

Scan Unicode **scalars** via `Lovelace.Common.Utf_8`. Do not treat Ada `Character` as a Lovelace character. For non-ASCII test data, encode with `Utf_8.Encode` (see [regex-engine.md](regex-engine.md) on `-gnatW8` / Latin-1).

**Continue character** (after the first):

- Valid UTF-8 scalar.
- Not a C0/C1 control.
- Not whitespace or a line terminator.
- Not Unicode Other_Format (rejects ZWJ and similar; a family-emoji ZWJ sequence is not one identifier).
- Not `@`.
- Not punctuation, except `_` (allowed anywhere).

**First character:** same as continue, except it must not be ASCII `0`..`9`. Other Unicode digits (for example `٢`) may start an identifier.

**`@` prefix:** `@` may start an identifier only after a delimiter (start of input, whitespace, or punctuation) and must be followed by at least one continue character. `@foo` is an identifier. `@` alone is `Unrecognized_Symbol`. `foo@bar` (no space) reports `Unrecognized_Symbol` at `@` — `@` is not glued onto the preceding identifier.

**Allowed:** `name`, `foo_bar`, `_x`, `foo2`, letters with diacritics (`café`), emoji and other symbols (`🚀`).

**Not identifier characters** (errors, not tokens): ASCII graphic punctuation other than `_` (`$` `%` `^` `~` `'` `?` and the rest of that set), plus Unicode punctuation blocks listed in the tokenizer body.

## Filename sharing

`Tokenize (Source_Text)` leaves `Filename` absent on every token.

`Tokenize (Source_Text, Filename)` stores one refcounted `Shared_Filename` on every token and every error. `Lovelace.Compiler.Source.Same_Storage` is true across that output. The text is immutable; nothing mutates the shared block.

## Errors

`Tokenizer_Error_Code` is expandable. `Internal_Error` is first (compiler-bug group).

| Code | Meaning |
| --- | --- |
| `Internal_Error` | Compiler bug, such as a hardcoded regex pattern failing to compile |
| `Unrecognized_Symbol` | Valid scalar that does not start a token (`+`, `,`, `"`, `2`, `@` alone, …) |
| `Invalid_Utf_8` | Bytes that are not valid UTF-8 |

There are no error tokens and no `null` tokens. The scanner collects **all** user-source errors in one pass (it does not stop at the first). After each error it skips one scalar, or one byte / invalid sequence for `Invalid_Utf_8`, and continues.

If any error is collected — user or internal — `Tokenize` returns `Ok => False` with the full error list. Recovered tokens from that pass are not returned.

A comma, plus, quote, or digit-only run is an **error**, not a token. `2foo` reports `Unrecognized_Symbol` at `2` (then `foo` may still be recognized during recovery; only the error list is returned).

Clean input such as `begin` succeeds (`Ok => True`). That also shows the built-in patterns compiled.

## Not yet tokenized

This slice does **not** emit tokens for:

- String literals (internal spaces will be kept when they exist)
- Character literals
- Numeric literals
- Comments
- Operators
- Comma (today: `Unrecognized_Symbol`)
- Keywords other than `program`, `begin`, `end`

## Tests

```powershell
alr -C compiler/tests run
```
