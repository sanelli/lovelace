# Numeric literals

`Lovelace.Compiler.Literals` interprets integer and float **lexemes** produced by the [tokenizer](tokenizer.md). It does not participate in parsing or codegen yet: literals are tokenized and tested, but not used in procedure bodies or calls.

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). Lexical shapes: [token-grammar.md](token-grammar.md).

## API

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Literals` | `Interpret_Integer`, `Interpret_Float`, Result-shaped outcomes |

```ada
function Interpret_Integer (Lexeme : String) return Integer_Literal_Results.Result;
function Interpret_Float (Lexeme : String) return Float_Literal_Results.Result;
```

Handle both `Ok` discriminants. Failure codes: `Internal_Error` (first) and `Invalid_Literal`.

## Integer forms

Optional leading `+` / `-`, optional Ada-style base prefix `#BASE#` with `BASE` in `{2, 8, 10, 16}`, digits valid for that base, optional `s` / `u` signedness, optional size `8` / `16` / `32` / `64`.

Examples: `42`, `-3`, `16#FF#`, `2#1010#u8`, `+7s32`.

## Float forms

Optional leading `+` / `-`, digits, required `.`, optional fraction digits, optional `e` / `E` exponent with optional sign.

Examples: `3.14`, `7.`, `1.0e-3`, `-2.5E+2`.

## Out of scope

- Using literals in statements or as call arguments
- Typing a literal into a Lovelace `integer` / `float` type expression
- Underscores in digit groups
