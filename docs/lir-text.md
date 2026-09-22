# LIR textual format (`.tlir`)

Version **1.0** of the Lovelace Intermediate Representation text file. Owned by crate `lovelace_lir` (`Lovelace.Lir.Text`). Overview of the IR: [lir.md](lir.md). Binary companion: [lir-binary.md](lir-binary.md).

UTF-8, no BOM. WAT-inspired S-expressions (LIR sits next to WASM, not Pascal). This slice **writes and prints only**; there is **no `.tlir` parser**.

The subroutine name+offset **preamble** exists only in `.lir`, not in `.tlir`.

## Canonical writer

Stable for tests:

- 2-space indent
- `LF` newlines
- no trailing spaces
- final newline
- no `;;` comments in the canonical writer (a future parser may allow them)

`(version 1 0)` is required and is the **text format** version (same 1.0 as binary).

## Grammar (writer shape)

Root form is `(module …)`.

Inside the module, in order:

1. `(version 1 0)`
2. `(name "…")` once
3. `(flags <decimal-u32>)` always present (v1 examples use `0`)
4. Optional `(origin …)` when a module origin is present (see below)
5. Zero or more `(depend "Name")` in insertion order
6. Zero or more `(subroutine …)` in insertion order

Inside a subroutine, in order:

1. `(name "…")`
2. Optional `(origin …)` when a subroutine origin is present
3. Optional `(param t1 t2 …)` — omit the whole form when there are zero parameters
4. **Required** `(result t)` — always present; use `unit` for procedures
5. Optional bare identifiers `export` and/or `entrypoint` (flag bits, not strings)
6. `(body …)` — may be empty

### Origin forms

Module origin (after `(flags …)`):

```text
(origin
  (filename "path.love")
  (name-span (position <byte> <line> <column>) (position <byte> <line> <column>))
  (span (position <byte> <line> <column>) (position <byte> <line> <column>)))
```

Subroutine origin (after `(name …)`): same shape but **without** `(span …)` (name-span only). Empty `(filename "")` means no filename was attached. Omit the whole `(origin …)` when the in-memory origin is absent.

`(version 1 0)` is unchanged; origin fields are part of the still-labeled 1.0 text layout.

Type tokens (canonical lowercase):

`unit` `i8` `i16` `i32` `i64` `i128` `u8` `u16` `u32` `u64` `u128` `f16` `f32` `f64`

Exactly one `(result …)` with a single type. **Never** invent a `void` token.

Only instruction token in v1: `noop` (lowercase). The canonical writer puts one instruction per line.

## Quoted strings

Names use double quotes. Escapes:

| Escape | Meaning |
| --- | --- |
| `\\` | backslash |
| `\"` | quote |
| `\n` | LF |
| `\r` | CR |
| `\t` | tab |
| `\u{HHHH}` | other C0 controls (hex digits) |

Other Unicode scalars (including emoji) are raw UTF-8 inside the quotes.

## Example

```text
(module
  (version 1 0)
  (name "example")
  (flags 0)
  (depend "other")
  (subroutine
    (name "Main")
    (param i32 f64)
    (result i32)
    export
    entrypoint
    (body
      noop))
  (subroutine
    (name "Init")
    (result unit)
    (body))
)
```

Empty module (no depends, no subroutines):

```text
(module
  (version 1 0)
  (name "example")
  (flags 0)
)
```

## Ada API

```ada
function To_Text (The_Module : Modules.Module) return To_Text_Result;
function Write (The_Module : Modules.Module; Path : String) return Write_Result;
function Print (The_Module : Modules.Module) return Write_Result;
```

`To_Text` runs `Validate` first and returns UTF-8 text or an `Error_Code`. `Write` writes those bytes to `Path` (convention `.tlir`). `Print` writes `To_Text` to standard output on success; on validation failure it does not print.
