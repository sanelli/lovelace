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
| `Lovelace.Compiler.Backend.Lowering` | `Lower` (Validate, Unit return, core param widening, `_start` / exports) |
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

If there is no entrypoint, no `_start` and no `wasi:cli/run` export are produced.

### Print integer intrinsic (`@intrinsic` → `Print_Integer_Stdout`)

When a LIR subroutine has `Intrinsic_Flag` and matches `augusta.std.io.print(integer)→Unit`, lowering **replaces** the empty body with a synthesized core function that:

1. Formats the `i32` parameter as decimal ASCII (optional `-`, no trailing newline; special-cases `Integer_32'First`).
2. Creates a `stream<u8>`, calls imported `wasi:cli/stdout@0.3.0` `write-via-stream`, writes the bytes, drops the writable end, and awaits the completion future (trap on failure / `BLOCKED`).

Emission then attaches the WASI 0.3 import graph (`wasi:cli/types@0.3.0` + `wasi:cli/stdout@0.3.0`), a tiny `$libc` core module (1-page `memory` + `cabi_realloc`), and canon builtins (`stream.new` / async `stream.write` / `stream.drop-writable` / async `future.read` / `future.drop-readable` / `canon lower` of `write-via-stream`). Guest functions live in a second core module that imports those builtins. Without that intrinsic, emission stays export-only (no stdout imports / memory). `@native` FFI bindings lower to an empty noop core body in this slice (no shared-library invoke yet).

## Exports

`Export_Flag` on LIR means **Lovelace visibility** (for `using` / cross-module calls). **WIT/component export** is emitted only when that subroutine also has **zero parameters**: it is canon-lifted under a **kebab-case** form of its LIR name (ASCII letters/digits lowercased; other bytes become `-`). Parameterized `Export_Flag` procedures lower to core functypes only (no `Core_Exported`, no WIT line) so Augusta-style `print(integer)` can exist without Canonical ABI export yet.

A nullary subroutine may be both entrypoint and export: then both `wasi:cli/run@0.3.0` and the named export appear. LIR names are always `Module.Proc`; core and component export strings use the kebab form (`Module.Proc` → `module-proc`). WAT `$` labels sanitize non-id bytes on the core function name (``.`` → `_2e`, or kebab `-` kept); when several LIR functions share a name (overloads), the label appends `_<1-based-index>` (e.g. `$Overload_2eSink_1`). Binary `call` remains by function index.

Component Model `externname`s must be kebab-case. Pure non-ASCII names (e.g. emoji) sanitize to `export` after dash collapse.

## Types (this slice)

| LIR signature | Supported |
| --- | --- |
| `Unit` return, no parameters | Yes → core `[] -> []`, WIT/component `func()` |
| `Unit` return, numeric parameters, **not** entrypoint (including `Export_Flag`) | Yes → core functype with widened params (see below); WIT kebab export only if nullary `Export_Flag` |
| Entrypoint wrapper `_start` | Yes → core `[] -> [i32]`, component `func() -> result` inside `wasi:cli/run` |
| Non-`Unit` return | No → `Unsupported_Type` |
| Entrypoint with parameters | No → `Unsupported_Type` |

### LIR → core WASM → WIT (when exported later)

Small integers widen to core `i32` / `i64`. WIT column is the Canonical ABI / WIT type for a future export of that parameter; this slice does not emit parameterful WIT exports yet.

| LIR | Core WASM | WIT (future export) |
| --- | --- | --- |
| `I8` | `i32` | `s8` |
| `I16` | `i32` | `s16` |
| `I32` | `i32` | `s32` |
| `I64` | `i64` | `s64` |
| `U8` | `i32` | `u8` |
| `U16` | `i32` | `u16` |
| `U32` | `i32` | `u32` |
| `U64` | `i64` | `u64` |
| `F32` | `f32` | `f32` |
| `F64` | `f64` | `f64` |

Example core WAT for a module procedure with parameters (exported or not; no WIT line when parameterized):

```wat
(func $Whatever (param i32 f32 f32)
)
```

LIR **locals** (flat list after parameters) lower to Wasm core locals after params. Nested declare scopes from source are already flattened in LIR; the backend maps each LIR local to a core local slot via `Map_Locals` / `Local_Types` (same type encoding as parameters). Example:

```wat
(func $Main (local i32 i64)
)
```

LIR `Local_Get` / `Local_Set` use **1-based** indices (parameters occupy the first slots, then flattened locals). The backend emits Wasm **`local.get` / `local.set` with 0-based indices** (`Local_Index - 1`).

In the component type section, bare `(result)` is a separate `defvaltype`; the `run` functype references it by type index (inline `0x6a` is not a valid `valtype`).

## Instructions (this slice)

| LIR | Lowering |
| --- | --- |
| Empty body | Empty core body + `end` |
| `No_Operation` | Skipped (not emitted) |
| `Constant_I32` | `i32.const` (core) |
| `Call` | `call` to the 1-based core function with the same index |
| `Local_Get` | `local.get` (0-based Wasm index = LIR index − 1) |
| `Local_Set` | `local.set` (0-based Wasm index = LIR index − 1) |
| `Intrinsic_Flag` + `Print_Integer_Stdout` | Synthesized decimal format + WASI 0.3 stdout write (locals, stores, stream/future builtins) |
| `Native_Flag` (`@native`) | Empty noop core body (FFI not wired yet) |

## Companion WIT

Shared printer (`Backend.Wit.To_Wit`). Example for module `Hello` with entrypoint + export `Helper`:

```wit
package love:hello@0.0.1;

world module {
  export helper: func();
  export wasi:cli/run@0.3.0;
}
```

Rules:

- Package name: `love:<sanitized-module-name>@<module-version>` (ASCII letters/digits lowercased; other bytes → `-`, consecutive dashes collapsed, edges stripped; empty → `module`).
- `export wasi:cli/run@0.3.0;` only when an entrypoint exists.
- One `export <kebab-name>: func();` per nullary `Export_Flag` subroutine (same sanitization; empty → `export`).
- WAT `$` ids: ASCII letters/digits/`_`/`-` kept; other bytes → `_HH` so emoji unit names stay valid in text.
- `import wasi:cli/stdout@0.3.0;` when a `Print_Integer_Stdout` intrinsic is present (component binary also imports `wasi:cli/types@0.3.0` for `error-code`).
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

- Full WASI `command` world imports beyond stdout + `wasi:cli/run@0.3.0`
- Browser / core-module-only default format
- Alexandria doc embedding in artifacts
- Linking LIR `Dependencies`
- Operators / control-flow beyond what LIR already lowers (assignment / local get-set are in this slice)

## Tests

Nested crate `lovelace_compiler_tests` covers export-only, entrypoint, both flags, two exports, noop bodies, const+call bodies, typed core parameters, print-integer intrinsic stdout synthesis, unsupported types, invalid modules, component preamble bytes, and Wasm/Wat WIT equality. Run with `alr -C lovelace/compiler/tests run`.

End-to-end CLI checks live in `lovelace/lovelace/integration_tests`: build samples, optionally `wasm-tools validate` every `.wasm`/`.wat`, and run entrypoint programs with `wasmtime` when present.
