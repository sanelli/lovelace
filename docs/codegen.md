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

LIR ownership and codecs: [lir.md](lir.md). Frontend lowering into LIR: [ir-generator.md](ir-generator.md). End-to-end builds: [cli.md](cli.md). Diagnostics: [diagnostics.md](diagnostics.md).

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

## Entrypoint: `_start` and `wasi:cli/run` (Option 1)

If any subroutine has `Entrypoint_Flag`:

1. Emit a synthetic core function named **`_start`** that `call`s the entrypoint, then `i32.const 0` (Canonical ABI success for empty `result`).
2. Canon-lift `_start` to a component function with type `func() -> result`.
3. Wrap that function in a component **instance** that exports it as `"run"`, and export the instance as **`wasi:cli/run@0.3.0`** (the name `wasmtime run` looks up).

This slice does **not** emit the full `wasi:cli/command` import graph. The artifact only exports the WASI CLI run instance (and Lovelace kebab-case exports). The package version `0.3.0` matches WASI 0.3 CLI run.

If there is no entrypoint, no `_start` and no `wasi:cli/run` export are produced.

## Exports

Every LIR subroutine with `Export_Flag` is canon-lifted and component-exported under a **kebab-case** form of its LIR name (ASCII letters/digits lowercased; other bytes become `-`). A subroutine may be both entrypoint and export: then both `wasi:cli/run@0.3.0` and the named export appear. Core module export names keep the original LIR spelling.

Component Model `externname`s must be kebab-case; PascalCase LIR identifiers such as `Hello` become `hello`.

## Types (this slice)

| LIR signature | Supported |
| --- | --- |
| `Unit` return, no parameters | Yes → core `[] -> []`, WIT/component `func()` |
| Entrypoint wrapper `_start` | Yes → core `[] -> [i32]`, component `func() -> result` inside `wasi:cli/run` |
| Any other `Value_Type` or parameters | No → `Unsupported_Type` |

`I128`, `U128`, `F16`, and other scalars remain deferred backend work.

In the component type section, bare `(result)` is a separate `defvaltype`; the `run` functype references it by type index (inline `0x6a` is not a valid `valtype`).

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
  export helper: func();
  export wasi:cli/run@0.3.0;
}
```

Rules:

- Package name: `love:<sanitized-module-name>@0.1.0` (ASCII letters/digits lowercased; every other byte → `-`; empty → `module`).
- `export wasi:cli/run@0.3.0;` only when an entrypoint exists.
- One `export <kebab-name>: func();` per `Export_Flag` subroutine.
- No `import` lines (Option 1).
- `Emit_Wasm` and `Emit_Wat` produce the same WIT string for the same LIR module.

## Running with Wasmtime

Artifacts are components. With an entrypoint, plain `wasmtime run` finds `wasi:cli/run@0.3.0`:

```text
wasmtime run -Sp3 -W component-model-async=y Hello.wasm
wasmtime run -Sp3 -W component-model-async=y Hello.wat
```

Named Lovelace exports can still be invoked explicitly:

```text
wasmtime run -Sp3 -W component-model=y --invoke 'hello()' Hello.wasm
```

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

- Full WASI `command` world imports (beyond exporting `wasi:cli/run@0.3.0`)
- Browser / core-module-only default format
- `cabi_realloc` / linear memory (not required for empty Unit ABI)
- Alexandria doc embedding in artifacts
- Linking LIR `Dependencies`
- Statement-rich instruction sets beyond `No_Operation`

## Tests

Nested crate `lovelace_compiler_tests` covers export-only, entrypoint, both flags, two exports, noop bodies, unsupported types, invalid modules, component preamble bytes, and Wasm/Wat WIT equality. Run with `alr -C compiler/tests run`.
