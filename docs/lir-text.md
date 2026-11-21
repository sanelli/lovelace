# LIR text format (`.tlir`)

Version **1.0** textual companion to the [binary LIR](lir-binary.md). Owned by crate `lovelace_lir` (`Lovelace.Lir.Text`). Overview: [lir.md](lir.md).

UTF-8, LF newlines. The writer (`To_Text` / `Write` / `Print`) is the source of truth for layout; there is no text reader yet.

## Grammar (writer shape)

Root form is `(module …)`.

Inside the module, in order:

1. `(version 1 0)`
2. `(name "…")` once
3. Optional `(flags <decimal-u32>)` — omit when the module flag word is `0` (v1 has no named module bits yet)
4. Optional `(origin …)` when a module origin is present (see below)
5. Zero or more `(depend "Name")` in insertion order
6. Optional `(index …)` when there is at least one subroutine (see below)
7. Zero or more `(subroutine …)` in insertion order

### Index form

Lists every subroutine’s **1-based id** (same as `call <index>`), source name, parameters, and result. Names may repeat for overloads.

```text
(index
  (1 "Sink" (param "V" i32) (result unit))
  (2 "Sink" (param "Flag" i32) (result unit))
  (3 "Run" (result unit))
)
```

Omit `(param …)` when there are zero parameters. Omit the whole `(index …)` when `subroutine_count` is 0.

Inside a subroutine, in order:

1. `(name "…")`
2. Optional `(origin …)` when a subroutine origin is present
3. Optional `(param "name1" t1 "name2" t2 …)` — alternating quoted parameter name and type token; omit the whole form when there are zero parameters
4. **Required** `(result t)` — always present; use `unit` for procedures
5. Optional `(flags …)` — space-separated flag names in this order when set: `export`, `entrypoint`, `native`, `intrinsic`. Omit the whole form when no bits are set
6. Optional `(native "library" "function")` when a `@native` FFI binding is present (same strings as the LIR binding; emit together with `native` in `(flags …)`). `@intrinsic` sets `intrinsic` in `(flags …)` only — no `(native …)` form
7. Optional `(locals (1 "name1" t1) (2 "name2" t2) …)` — 1-based index among locals (not the `local.get` slot), quoted name, type token; omit when there are zero locals
8. Optional `(body …)` — omit when the instruction sequence is empty (native and intrinsic bodies are always empty)

### Origin forms

Module origin (after `(flags …)` when present, else after `(name …)`):

```text
(origin
  (filename "/absolute/path/to/unit.love")
  (name-span (position <byte> <line> <column>) (position <byte> <line> <column>))
  (span (position <byte> <line> <column>) (position <byte> <line> <column>)))
```

Subroutine origin (after `(name …)`): same shape as the module origin — `(filename …)`, `(name-span …)`, and `(span …)` for the whole procedure declaration. Empty `(filename "")` means no filename was attached. Omit the whole `(origin …)` when the in-memory origin is absent.

CLI builds absolutize the root `.love` path before tokenize / IR; dependency paths from module resolution are already absolute. Origin `(filename …)` therefore carries a full path for both the root module and imported units.

`(version 1 0)` is unchanged; origin fields are part of the still-labeled 1.0 text layout.

Type tokens (canonical lowercase):

`unit` `i8` `i16` `i32` `i64` `u8` `u16` `u32` `u64` `f32` `f64`

(`i128`, `u128`, and `f16` are not in this closed set yet.)

Exactly one `(result …)` with a single type. **Never** invent a `void` token.

Instruction forms (lowercase; one parenthesized instruction per line in the canonical writer):

| Form | Meaning |
| --- | --- |
| `(noop)` | `No_Operation` |
| `(i32.const <decimal>)` | `Constant_I32` (signed decimal, no leading `+`) |
| `(call <index>)` | `Call` (1-based subroutine index, decimal) |
| `(local.get <index>)` | `Local_Get` (1-based; params first, then flattened locals) |
| `(local.set <index>)` | `Local_Set` (1-based; params first, then flattened locals) |

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
  (depend "other")
  (index
    (1 "Main" (param "x" i32 "y" f64) (result i32))
    (2 "Init" (result unit)))
  (subroutine
    (name "Main")
    (param "x" i32 "y" f64)
    (result i32)
    (flags export entrypoint)
    (body
      (noop))
  )
  (subroutine
    (name "Init")
    (result unit)
  )
)
```

Empty module (no depends, no subroutines, zero flags):

```text
(module
  (version 1 0)
  (name "example")
)
```

## Ada API

```ada
function To_Text (The_Module : Modules.Module) return To_Text_Result;
function Write (The_Module : Modules.Module; Path : String) return Write_Result;
function Print (The_Module : Modules.Module) return Write_Result;
```

`To_Text` runs `Validate` first and returns UTF-8 text or an `Error_Code`. `Write` writes those bytes to `Path` (convention `.tlir`). `Print` writes `To_Text` to standard output on success; on validation failure it does not print.
