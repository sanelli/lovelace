# Lovelace Intermediate Representation (LIR)

Crate `lovelace_lir` (`lir/`) owns the in-memory LIR types, builders, validation, and the versioned **binary** (`.lir`) and **textual** (`.tlir`) formats. It is a **static** library and depends only on `lovelace_common`. It does not emit WASM, WIT, or WAT — those live in the compiler backends ([codegen.md](codegen.md)).

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). Format layouts:

| Format | Doc |
| --- | --- |
| Binary `.lir` | [lir-binary.md](lir-binary.md) |
| Textual `.tlir` | [lir-text.md](lir-text.md) |

This slice has **no `.tlir` parser**. Text support is write and print only (`To_Text`, `Write`, `Print`). Analysis and optimization passes are not in the crate until asked.

## Machine model

LIR is a **stack machine** with sequential (linear) byte memory, in the spirit of WASM core.

- The operand stack is **implicit** at run time; it is not stored in the module.
- Opcodes are **Lovelace** 16-bit codes (little-endian `u16` in the stream), **not** WASM opcode bytes. The compiler backend lowers LIR to WASM / WAT / WIT ([codegen.md](codegen.md)).
- An instruction is an opcode word plus zero or more immediate bytes. Use `Immediate_Length` / `Encoded_Length` for the stream size of each opcode.

## Value types (closed set)

| Ada `Value_Type` | Token / role |
| --- | --- |
| `Unit` | `unit` — no stack value |
| `I8` … `I128` | `i8` … `i128` — signed integers |
| `U8` … `U128` | `u8` … `u128` — unsigned integers |
| `F16` `F32` `F64` | `f16` `f32` `f64` — floating point |

**There is no `void` type.** Procedures are subroutines whose return type is **`unit`**.

Every subroutine **must** have a return type. Returning `unit` tells the Lovelace backend the subroutine is a procedure and pushes nothing on the operand stack. A non-`unit` return type pushes one value of that type.

No references or aggregates are in the closed set until specified. `I128`, `U128`, and `F16` are first-class in LIR; mapping them (and `unit`) to WASM is a backend concern.

Binary codes are `0` … `13` in enumeration order (`To_Code` / `From_Code`). See [lir-binary.md](lir-binary.md).

## Modules and subroutines

A **module** has:

- a UTF-8 **name**
- a `u32` **flags** bitset (not string tags; no named bits in this slice)
- zero or more **dependencies** (other module names, not file paths)
- zero or more **subroutines**
- an optional **origin** (`Module_Origin`: name span, unit span, optional shared filename from `Lovelace.Common.Source`), persisted in `.lir` / `.tlir` (version numbers stay **1.0**)

A **subroutine** has:

- a **signature**: UTF-8 name, **mandatory** return type, zero or more unnamed parameter types
- **flags** (`export` = bit 0, `entrypoint` = bit 1)
- an instruction body (may be empty)
- an optional **origin** (`Subroutine_Origin`: name span, optional shared filename), persisted in `.lir` / `.tlir` (version numbers stay **1.0**)

Origins support diagnostics and frontend lowering. Codecs round-trip them when present (`origin_present = 0` / omit text form when absent). `Validate` does not require origins. Shared position types live in [`Lovelace.Common.Source`](source-locations.md); the compiler copies them via the [IR Generator](ir-generator.md). The format **version fields remain 1.0**; only the layout gained origin fields. The CLI writes `.lir` under the build output `obj/` folder ([cli.md](cli.md)); user diagnostics use `LV#####` codes ([diagnostics.md](diagnostics.md)).

The only opcode in this slice is `No_Operation` (`noop` in text).

## Ada packages

| Package | Role |
| --- | --- |
| `Lovelace.Lir` | Crate root |
| `Lovelace.Lir.Types` | `Value_Type`, sequences, `To_Code` / `From_Code` |
| `Lovelace.Lir.Opcodes` | `Opcode`, `To_Word` / `From_Word`, lengths |
| `Lovelace.Lir.Instructions` | Discriminated `Instruction`, sequences |
| `Lovelace.Lir.Subroutines` | `Signature`, flags, body builders, optional origin |
| `Lovelace.Lir.Modules` | Module builders, optional origin, and `Validate` |
| `Lovelace.Lir.Errors` | Shared `Error_Code` and validation `Result` |
| `Lovelace.Lir.Binary` | Encode / Decode / Read / Write `.lir` |
| `Lovelace.Lir.Text` | `To_Text` / `Write` / `Print` `.tlir` |

Builders allow temporarily invalid modules (for example two entrypoints while appending). **Encode**, **Write**, **To_Text**, and **Print** call `Validate` first and fail on:

- empty module, dependency, or subroutine name
- invalid UTF-8 in any name
- duplicate dependency or subroutine names
- self-dependency (a depend name equals the module name)
- more than one `Entrypoint` flag

Decode applies the same checks plus format errors (bad magic, truncated input, unknown type code, and so on). Handle both success and failure on every `Result`-shaped return (see the Result rule).

## Tests

Nested crate `lovelace_lir_tests` (`lir/tests`) covers types, binary round-trips and decode failures, text goldens, validation, and optional origins. Run with `alr -C lir/tests run`.
