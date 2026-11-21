# LIR text format (`.tlir`)

Version **1.0** textual companion to the [binary LIR](lir-binary.md). Owned by crate `lovelace_lir` (`Lovelace.Lir.Text`). Overview: [lir.md](lir.md).

UTF-8, LF newlines. The writer (`To_Text` / `Write` / `Print`) is the source of truth for layout; there is no text reader yet.

## Grammar (writer shape)

Root form is `(module …)`.

Inside the module, in order:

1. `(lir-version 1 0)`
2. `(module-version "…")` once (default `"0.0.1"`)
3. `(name "…")` once
4. Optional `(flags <decimal-u32>)` — omit when the module flag word is `0` (v1 has no named module bits yet)
5. Optional `(origin …)` when a module origin is present (see below)
6. Zero or more `(dependency "Name")` in insertion order
7. Optional `(index …)` when there is at least one subroutine (see below)
8. Zero or more `(subroutine …)` in insertion order

### Index form

Lists every subroutine’s **1-based id** (same as `call <index>`), source name, parameters, and result. Names may repeat for overloads.

```text
(index
  (1 "Demo.Sink" (param "V" i32) (result unit))
  (2 "Demo.Sink" (param "Flag" i32) (result unit))
  (3 "Demo.Run" (result unit))
)
```

Omit `(param …)` when there are zero parameters. Omit the whole `(index …)` when `subroutine_count` is 0.

Inside a subroutine, in order:

1. `(name "Module.Proc")` — always qualified `MODULE.NAME`
2. Optional `(from-dependency "Module")` when the subroutine was flattened from a non-root unit
3. Optional `(origin …)` when a subroutine origin is present
4. **Required** `(result t)` — always present; use `unit` for procedures
5. Optional `(flags …)` — space-separated flag names in this order when set: `export`, `entrypoint`, `native`, `intrinsic`. Omit the whole form when no bits are set
6. Optional `(native "library" "function")` when a `@native` FFI binding is present (same strings as the LIR binding; emit together with `native` in `(flags …)`). `@intrinsic` sets `intrinsic` in `(flags …)` only — no `(native …)` form
7. Optional `(locals …)` — unified parameter + local list in **`local.get` / `local.set` order** (params first). Each entry is `(<1-based-slot> "name" <type>)` or `(<slot> "name" <type> param)` when the slot is a parameter. Omit when there are neither parameters nor locals
8. Optional `(body …)` — omit when the instruction sequence is empty (native and intrinsic bodies are always empty)

There is **no** separate `(param …)` form on the subroutine body; the module `(index …)` header still uses compact `(param …)` for the call signature.

### Origin forms

Module origin (after `(flags …)` when present, else after `(name …)`):

```text
(origin
  (filename "/absolute/path/to/unit.love")
  (name-span (position (byte <b>) (row <r>) (column <c>)) (position (byte <b>) (row <r>) (column <c>)))
  (span (position (byte <b>) (row <r>) (column <c>)) (position (byte <b>) (row <r>) (column <c>))))
```

Subroutine origin (after `(name …)`): same shape as the module origin — `(filename …)`, `(name-span …)`, and `(span …)` for the whole procedure declaration. Empty `(filename "")` means no filename was attached. Omit the whole `(origin …)` when the in-memory origin is absent.

CLI compiles absolutize the root `.love` path before tokenize / IR; dependency paths from module resolution are already absolute. Origin `(filename …)` therefore carries a full path for both the root module and imported units.

`(lir-version 1 0)` labels the text layout; `(module-version …)` defaults to `"0.0.1"`.

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
  (lir-version 1 0)
  (module-version "0.0.1")
  (name "example")
  (dependency "other")
  (index
    (1 "example.Main" (param "x" i32 "y" f64) (result i32))
    (2 "example.Init" (result unit)))
  (subroutine
    (name "example.Main")
    (result i32)
    (flags export entrypoint)
    (locals (1 "x" i32 param) (2 "y" f64 param))
    (body
      (noop))
  )
  (subroutine
    (name "example.Init")
    (result unit)
  )
)
```

Empty module (no dependencies, no subroutines, zero flags):

```text
(module
  (lir-version 1 0)
  (module-version "0.0.1")
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
