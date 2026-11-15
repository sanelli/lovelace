# Numeric literals

`Lovelace.Compiler.Literals` interprets integer and float **lexemes** produced by the [tokenizer](tokenizer.md), and evaluates integer literals to `Integer_32` for call-argument lowering.

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). Lexical shapes: [token-grammar.md](token-grammar.md).

## API

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Literals` | `Interpret_Integer`, `Interpret_Float`, `To_Integer_32`, Result-shaped outcomes |

```ada
function Interpret_Integer (Lexeme : String) return Integer_Literal_Results.Result;
function Interpret_Float (Lexeme : String) return Float_Literal_Results.Result;
function To_Integer_32 (The_Value : Integer_Literal_Value) return Integer_32_Results.Result;
function To_Integer_32 (Lexeme : String) return Integer_32_Results.Result;
```

Handle both `Ok` discriminants. Failure codes: `Internal_Error` (first) and `Invalid_Literal`.

`To_Integer_32` range-checks against `Interfaces.Integer_32'First .. Integer_32'Last` (including `-2147483648`). Size/signedness suffixes on the lexeme are preserved by `Interpret_Integer` but do not change the evaluate range in this slice.

## Integer forms

Optional leading `+` / `-`, optional Ada-style base prefix `#BASE#` with `BASE` in `{2, 8, 10, 16}`, digits valid for that base, optional `s` / `u` signedness, optional size `8` / `16` / `32` / `64`.

Examples: `42`, `-3`, `16#FF#`, `2#1010#u8`, `+7s32`.

## Float forms

Optional leading `+` / `-`, digits, required `.`, optional fraction digits, optional `e` / `E` exponent with optional sign.

Examples: `3.14`, `7.`, `1.0e-3`, `-2.5E+2`.

## Out of scope

- Evaluating float literals to `Float_32` / `Float_64`
- Typing a literal into a Lovelace `integer` / `float` type expression beyond call-arg checks
- Underscores in digit groups
