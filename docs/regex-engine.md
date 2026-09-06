# Host UTF-8 and regex engine

The `lovelace_common` crate provides host UTF-8 helpers and a small Thompson NFA regular-expression engine. Both treat Ada `String` as a **UTF-8 byte sequence**, not as Latin-1 code units.

This page is for host Ada. Public Ada APIs remain documented on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md).

## Not the Lovelace lexer

`Lovelace.Common.Regex` is a **host** library used by the toolchain. It is **not** the Lovelace language lexer or tokenizer:

- No token stream, no `compiler/` code, no source locations for `.love` files.
- AUnit tests under `common/tests/` prove that a pattern can match each planned token *class*; that is not a lexer.

A future lexer may call `Compile` / `Match_Prefix`, but language syntax and diagnostics live elsewhere.

## UTF-8 conventions

| Concept | Representation |
| --- | --- |
| Host / Lovelace **string** text | UTF-8 bytes in Ada `String` / `Unbounded_String` |
| Lovelace **character** (one scalar) | `Wide_Wide_Character` / `Lovelace.Common.Utf_8.Code_Point` (four bytes) |
| Ada sources and `.love` sources | UTF-8 (`-gnatW8` on host crates) |

`Lovelace.Common.Utf_8` provides `Sequence_Length`, `Decode`, and `Encode`. Invalid UTF-8 sequences and surrogate / out-of-range scalars are reported via `Utf_8_Error` (an internal error, not a user diagnostic).

**Byte lengths:** ASCII is one byte; many Latin letters with diacritics are two; BMP symbols are often three; supplementary-plane scalars (for example U+1F680) are four. `Match_Prefix` returns a length in **bytes**, not in scalars.

**Ada string literals:** with `-gnatW8`, non-ASCII characters in a `String` literal that fit in Latin-1 are stored as single `Character` values (not UTF-8). Scalars above U+00FF cannot appear in a `String` literal. For true UTF-8 test or host data, encode with `Utf_8.Encode` (or build bytes explicitly).

## Regex engine

Package: `Lovelace.Common.Regex`.

1. `Compile (Pattern)` — parse a UTF-8 pattern into a Thompson NFA (`Regex_Result`).
2. `Match_Prefix (The_Engine, Input, From)` — longest accepting prefix of `Input` starting at byte index `From`, as a byte length.

Semantics:

- Matching advances by **Unicode scalars**, not by raw bytes.
- Invalid UTF-8 in `Input` does not match.
- Empty-only matches return `0` (no match of length at least 1).
- Alternation prefers the **longest** successful match among accepting prefixes.

Compile failures use `Regex_Error` (`Invalid_Utf_8` or `Parse_Error`) — again an internal error shape, not a Lovelace user diagnostic.

### Pattern syntax (subset)

| Construct | Meaning |
| --- | --- |
| Literal scalar | Matches that scalar (including multi-byte UTF-8 in the pattern source) |
| `.` | Any single scalar |
| `a\|b` | Alternation |
| `ab` | Concatenation |
| `a*` / `a+` / `a?` | Star / plus / optional (greedy longest prefix) |
| `(…)` | Grouping |
| `[…]` / `[^…]` | Character class / negated class; ranges with `-` |
| `\n` `\t` `\r` `\f` `\e` `\\` | Escapes (LF, HT, CR, FF, ESC, backslash) |
| `\u{hex}` | One Unicode scalar (1–6 hex digits; no surrogates) |
| `\|` `(` `)` `*` `+` `?` `[` `]` `.` `-` `^` `$` `%` `/` `{` `}` `"` `'` | Escapable metacharacters / punctuation when needed as literals |

Unsupported escapes and malformed classes or groups fail `Compile`.

### Example

```ada
declare
   Result : constant Lovelace.Common.Regex.Regex_Result :=
     Lovelace.Common.Regex.Compile ("\u{1F680}|go");
begin
   case Result.Ok is
      when True =>
         --  Match_Prefix returns the byte length of the longest prefix.
         null;
      when False =>
         null;  --  Result.Error
   end case;
end;
```

## Tests

Run the nested AUnit crate:

```powershell
alr -C common/tests run
```

That suite exercises engine mechanics and one pattern per planned Lovelace token class (comments, strings, characters, operators, keywords, identifiers, and so on) without implementing a tokenizer.
