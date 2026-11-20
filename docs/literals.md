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

Optional leading `+` / `-`, then one of:

| Prefix | Base | Digits |
| --- | --- | --- |
| *(none)* | 10 | `0`–`9` |
| `0b` / `0B` | 2 | `0`–`1` |
| `0o` / `0O` | 8 | `0`–`7` |
| `0x` / `0X` | 16 | `0`–`9`, `A`–`F`, `a`–`f` |

Optional `s` / `u` signedness, optional size `8` / `16` / `32` / `64`.

Examples: `42`, `-3`, `0xFF`, `0b1010u8`, `0o755`, `+0Xdeads32`.

Ada-style `#BASE#` forms are **not** supported (they fail tokenization).

## Float forms

Optional leading `+` / `-`, then one of:

1. `digits . [digits] [exponent] [width]` — e.g. `3.14`, `7.`, `1.0e-3`, `2.3f64`
2. `digits exponent [width]` — e.g. `1e3`, `1E3f32`
3. `digits width` — e.g. `7f32`, `0F64` (width required when there is no `.` / exponent)

Where `exponent = (e|E) [+|-] digits` and `width = f32|F32|f64|F64`.

| Lexeme shape | Resolved width (`Float_Literal_Value.The_Width`) |
| --- | --- |
| Has `.` and/or exponent, no width suffix | `float<32>` (`Bits_32`) |
| Trailing `f32` / `F32` | `float<32>` |
| Trailing `f64` / `F64` | `float<64>` |

There is **no** lone `f` / `F` suffix. Hex integers such as `0xf` / `0xF32` stay integers (based prefix wins). Type-position bare `float` remains an alias of `float<32>` (parser default unchanged by this slice).

## Out of scope

- Evaluating float literals to `Float_32` / `Float_64`
- Typing a literal into a Lovelace `integer` / `float` type expression beyond call-arg checks
- Underscores in digit groups
