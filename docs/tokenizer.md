# Compiler tokenizer

`Lovelace.Compiler.Tokenizer` turns UTF-8 source into a token sequence, or a list of located errors. It lives in crate `lovelace_compiler` and uses the host [regex engine](regex-engine.md) (`Compile` / `Match_Prefix`) for whitespace, identifiers, punctuation, and numeric literals.

This slice covers keywords, identifiers, punctuation for units and type lists, integer/float literals, flavor **directives** (`#if` / `#elsif` / `#else` / `#end`), double-quoted **string literals** (no escapes), and **`{` … `}` block comments** (non-nesting; skipped like whitespace). A recursive-descent parser for program and module compilation units is documented in [parser.md](parser.md) and [compilation-unit-grammar.md](compilation-unit-grammar.md). Flavor selection: [directives.md](directives.md). Literal lexeme interpretation (not wired into bodies yet) is in [literals.md](literals.md).

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). The token grammar for this slice is in [token-grammar.md](token-grammar.md).

## API

| Package | Role |
| --- | --- |
| `Lovelace.Common.Source` | `Source_Position`, `Source_Span`, refcounted `Shared_Filename`, `Filename_Option` — see [source-locations.md](source-locations.md) |
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

Empty source, whitespace-only source, and comment-only source succeed with an empty token sequence.

## Token kinds

| `Token_Kind` | Subtype | This slice |
| --- | --- | --- |
| `Keyword` | `Keyword_Subtype` | `program`, `module`, `begin`, `end`, `export`, `import`, `procedure`, `integer`, `float`, `signed`, `unsigned` |
| `Identifier` | (none) | Names, including `@foo`, `café`, emoji |
| `Punctuation` | `Punctuation_Subtype` | `;` `.` `(` `)` `,` `:` `<` `>` `=` |
| `Integer_Literal` | (none) | Optional sign, `0b`/`0o`/`0x` or decimal, optional `s`/`u` size (see [token-grammar.md](token-grammar.md)) |
| `Float_Literal` | (none) | Decimal forms with `.`, exponent, and/or `f32`/`f64` width |
| `Directive` | `Directive_Subtype` | `#if`, `#elsif`, `#else`, `#end` |
| `String_Literal` | (none) | `"…"` with no escapes; Lexeme includes both quotes |

Keywords are **case-sensitive**. `Program`, `Module`, `BEGIN`, `Procedure`, `Export`, `Native`, and `End` are identifiers. `#end` is a **directive**, distinct from keyword `end`.

The scanner matches a full identifier first, then classifies. `programmer` is one identifier, not `program` plus `mer`. `programbegin`, `modulex`, and `exporter` are identifiers.

Longest-match scan order: float → integer → directive → string → identifier → punctuation. Exact directive forms (`#if`, …) still match; old `#BASE#` integer spellings fail tokenization.

Float literal patterns are tried **before** integer patterns so `1.0`, `1e3`, and `7f32` are each a single `Float_Literal`.

Lexeme text is not stored on the token. Recover it with `Lexeme (Source_Text, The_Token)`, which slices `Source_Text (First.Byte_Index .. Last.Byte_Index)`. `Last.Byte_Index` is the **last byte** of the last scalar (the span covers the full UTF-8 sequence). For strings, the Lexeme includes the surrounding `"` characters; the parser strips them when reading a flavor name.

`Source_Position` stores 1-based `Byte_Index`, `Line`, and `Column`. Column counts Unicode scalars on the line; tab is one column. LF, CR, and CRLF (one line break) update line and column.

## Whitespace

Any space between tokens is **ignored**: consumed, not emitted, not attached to the previous or next token. That includes ASCII space, tab, LF, CR, FF, Unicode space separators, and line terminators (NBSP, NEL, ideographic space, and similar). Adjacent tokens with no space (`end;`) are valid.

Spaces **inside** a string literal are kept as part of the string token.

## Comments

Block comments use Ada-style **`{` … `}`** delimiters. They are **ignored like whitespace**: consumed, not emitted, not part of adjacent tokens. Empty `{}` is valid. Comments may span lines; line/column advance through the body the same way as for other multi-line spans.

**No nesting:** a `{` inside an open comment is `Nested_Comment` (`LV00023`). An opening `{` with no closing `}` before EOF is `Unterminated_Comment` (`LV00022`). A `}` outside a comment is `Stray_Comment_Closer` (`LV00024`).

`{` / `}` are **not** punctuation in this slice — they are reserved as comment delimiters only. Inside a string literal, braces are ordinary characters and do not start or end a comment.

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

**Not identifier characters** (errors, not tokens): ASCII graphic punctuation other than `_` and the punctuation subtypes above (`$` `%` `^` `~` `'` `?` and the rest of that set), plus Unicode punctuation blocks listed in the tokenizer body.

## Filename sharing

`Tokenize (Source_Text)` leaves `Filename` absent on every token.

`Tokenize (Source_Text, Filename)` stores one refcounted `Shared_Filename` on every token and every error. `Lovelace.Common.Source.Same_Storage` is true across that output. The text is immutable; nothing mutates the shared block. See [source-locations.md](source-locations.md).

## Errors

`Tokenizer_Error_Code` is expandable. `Internal_Error` is first (compiler-bug group).

| Code | Meaning |
| --- | --- |
| `Internal_Error` | Compiler bug, such as a hardcoded regex pattern failing to compile |
| `Unrecognized_Symbol` | Valid scalar that does not start a token (`+` alone, `#` not starting a directive, …) |
| `Invalid_Utf_8` | Bytes that are not valid UTF-8 |
| `Unterminated_String` | Opening `"` without a closing `"` before end of file |
| `Unterminated_Comment` | Opening `{` without a closing `}` before end of file (`LV00022`) |
| `Nested_Comment` | `{` found inside an open `{` … `}` comment (`LV00023`) |
| `Stray_Comment_Closer` | `}` outside a comment (`LV00024`) |

There are no error tokens and no `null` tokens. The scanner collects **all** user-source errors in one pass (it does not stop at the first). After each error it skips one scalar, or one byte / invalid sequence for `Invalid_Utf_8`, and continues. Comment errors recover the same way (advance past the offending `{` / `}` or report at EOF for unterminated).

If any error is collected — user or internal — `Tokenize` returns `Ok => False` with the full error list. Recovered tokens from that pass are not returned.

Clean input such as `begin` succeeds (`Ok => True`). That also shows the built-in patterns compiled.

## Not yet tokenized

This slice does **not** emit tokens for:

- Character literals
- Operators beyond the punctuation list above
- Line comments (`--`, `//`, …) — only `{` … `}` block comments are recognized

## Tests

```powershell
alr -C compiler/tests run
```
