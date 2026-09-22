# Compiler backends (LIR → WASM / WAT / WIT)

Crate `lovelace_compiler` lowers a validated LIR module into a WebAssembly **component** and a companion WIT file. Two emitters share one lowering and one WIT printer:

| API | Primary artifact | Companion |
| --- | --- | --- |
| `Lovelace.Compiler.Backend.Wasm.Emit_Wasm` | `.wasm` component bytes | `.wit` text |
| `Lovelace.Compiler.Backend.Wat.Emit_Wat` | `.wat` component text | `.wit` text (identical for the same LIR input) |

Neither emitter calls Tokenize, Parse, or Ir_Generator. Input is a `Lovelace.Lir.Modules.Module`.

## Pipeline

```text
Ast.Module  →  Ir_Generator.Generate  →  Lir.Modules.Module
                                              ↓
                                    Backend.Lowering.Lower
                                              ↓
                                    Backend.Model.Component_Model
                                         ↙         ↘
                              Backend.Wasm      Backend.Wat
                                   +                +
                              Backend.Wit      Backend.Wit
```

LIR ownership and codecs: [lir.md](lir.md). Frontend lowering into LIR: [ir-generator.md](ir-generator.md).

## Ada packages

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Backend` | Shared `Backend_Error`, `Byte_Sequence`, emit result shapes |
| `Lovelace.Compiler.Backend.Model` | In-memory component sketch after lowering |
| `Lovelace.Compiler.Backend.Lowering` | `Lower` (Validate, Unit-only check, `_start` / exports) |
| `Lovelace.Compiler.Backend.Wit` | Companion WIT printer |
| `Lovelace.Compiler.Backend.Leb128` | Unsigned / signed LEB128 for binary emit |
| `Lovelace.Compiler.Backend.Wasm` | Component binary encoder |
| `Lovelace.Compiler.Backend.Wat` | Component text encoder |

## Artifact target

Default output is a **component** ([Binary.md](https://github.com/WebAssembly/component-model/blob/main/design/mvp/Binary.md)):

| | Bytes 0–3 | Bytes 4–7 |
| --- | --- | --- |
| Core module | `\0asm` | `01 00 00 00` |
| Component (this slice) | `\0asm` | `0d 00 01 00` (version `0x0d`, layer 1) |

One LIR module maps to one component. Each LIR subroutine maps to one core function (same UTF-8 name).

## Entrypoint: `_start` and `run` (Option 1)

If any subroutine has `Entrypoint_Flag`:

1. Emit a synthetic core function named **`_start`** that `call`s the entrypoint, then `i32.const 0` (Canonical ABI success for empty `result`).
2. Canon-lift `_start` and component-export it as **`run`** with type `func() -> result` (same shape as [`wasi:cli/run`](https://github.com/WebAssembly/WASI/blob/main/wasip2/cli/run.wit)).

This slice does **not** emit the full `wasi:cli/command` import graph. Hosts that need WASI imports must supply them later; the artifact only exports `run` (and Lovelace exports).

If there is no entrypoint, no `_start` and no `run` export are produced.

## Exports

Every LIR subroutine with `Export_Flag` is canon-lifted and component-exported under its LIR name. A subroutine may be both entrypoint and export: then both `run` and the named export appear.

## Types (this slice)

| LIR signature | Supported |
| --- | --- |
| `Unit` return, no parameters | Yes → core `[] -> []`, WIT/component `func()` |
| Entrypoint wrapper `_start` | Yes → core `[] -> [i32]`, component `func() -> result` |
| Any other `Value_Type` or parameters | No → `Unsupported_Type` |

`I128`, `U128`, `F16`, and other scalars remain deferred backend work.

## Instructions (this slice)

| LIR | Lowering |
| --- | --- |
| Empty body | Empty core body + `end` |
| `No_Operation` | Skipped (not emitted) |

## Companion WIT

Shared printer (`Backend.Wit.To_Wit`). Example for module `Hello` with entrypoint + export `Helper`:

```wit
package love:hello@0.1.0;

world module {
  export run: func() -> result;
  export Helper: func();
}
```

Rules:

- Package name: `love:<sanitized-module-name>@0.1.0` (ASCII letters/digits lowercased; every other byte → `-`; empty → `module`).
- `export run: func() -> result;` only when an entrypoint exists.
- One `export <Name>: func();` per `Export_Flag` subroutine.
- No `import` lines (Option 1).
- `Emit_Wasm` and `Emit_Wat` produce the same WIT string for the same LIR module.

## Errors

```ada
type Backend_Error_Code is (Internal_Error, Unsupported_Type, Invalid_Module);
```

| Code | Meaning |
| --- | --- |
| `Internal_Error` | Compiler bug (listed first) |
| `Unsupported_Type` | Signature this slice cannot lower |
| `Invalid_Module` | `Modules.Validate` failed |

Each failure carries a UTF-8 `Detail` string.

## Out of scope

- Full WASI `command` world imports
- Browser / core-module-only default format
- `cabi_realloc` / linear memory (not required for empty Unit ABI)
- Alexandria doc embedding in artifacts
- CLI `lovelace build`
- Linking LIR `Dependencies`
- Statement-rich instruction sets beyond `No_Operation`

## Tests

Nested crate `lovelace_compiler_tests` covers export-only, entrypoint, both flags, two exports, noop bodies, unsupported types, invalid modules, component preamble bytes, and Wasm/Wat WIT equality. Run with `alr -C compiler/tests run`.
