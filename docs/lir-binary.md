# LIR binary format (`.lir`)

Version **1.0** of the Lovelace Intermediate Representation binary file. Owned by crate `lovelace_lir` (`Lovelace.Lir.Binary`). Overview of the IR: [lir.md](lir.md). Textual companion: [lir-text.md](lir-text.md).

Little-endian throughout. Integers are fixed-width (`u16` / `u32`), **not** WASM LEB128. The file is one linear image (no WASM-style section ids in v1).

File offsets in the subroutine preamble are **0-based** from the first magic byte.

## Header (8 bytes)

| Offset | Size | Value |
| --- | --- | --- |
| 0–3 | 4 | Magic `4C 49 52 00` (ASCII `LIR` plus NUL) |
| 4–5 | `u16` | `Format_Major` = `1` |
| 6–7 | `u16` | `Format_Minor` = `0` |

Wrong magic → `Invalid_Magic`. Any version other than major `1` / minor `0` → `Unsupported_Version`.

## Encoded string

Every name uses the same encoding:

1. `u32` byte length `N`
2. `N` bytes of UTF-8 (no terminator)

`N = 0` is an empty string (rejected for names by validation). Invalid UTF-8 in a name → `Invalid_Utf_8`.

## Encoded `Value_Type`

One `u8` code:

| Code | Type | Text token |
| --- | ---: | --- |
| 0 | `Unit` | `unit` |
| 1 | `I8` | `i8` |
| 2 | `I16` | `i16` |
| 3 | `I32` | `i32` |
| 4 | `I64` | `i64` |
| 5 | `I128` | `i128` |
| 6 | `U8` | `u8` |
| 7 | `U16` | `u16` |
| 8 | `U32` | `u32` |
| 9 | `U64` | `u64` |
| 10 | `U128` | `u128` |
| 11 | `F16` | `f16` |
| 12 | `F32` | `f32` |
| 13 | `F64` | `f64` |

Any other byte → `Unknown_Type`. There is no `void` code.

## Layout after the header

### Module metadata

1. Module name (encoded string)
2. `flags` — `u32` (v1 writers emit `0`; readers store the value as-is so future bits can round-trip; v1 does **not** reject nonzero flags)
3. `dependency_count` — `u32`
4. `dependency_count` encoded strings (depended-on **module names**, not paths)
5. **Module origin** (see below)

### Module origin

Immediately after dependencies, before the subroutine preamble:

1. `origin_present` — `u8` (`0` = absent, `1` = present; any other value → `Invalid_Presence`)
2. When present:
   - filename (encoded string; length `0` means no filename / absent option)
   - `name_span` — encoded `Source_Span` (module name)
   - `span` — encoded `Source_Span` (whole compilation unit)

#### Encoded `Source_Position`

Three `u32` fields: `Byte_Index`, `Line`, `Column` (each must be ≥ 1).

#### Encoded `Source_Span`

`First` position, then `Last` position.

### Subroutine preamble (binary only)

Not present in `.tlir`. After metadata, before subroutine records. Intended for future import scanning: list names and jump to definitions without parsing every record.

1. `subroutine_count` — `u32`
2. For each subroutine, in order:
   - name (encoded string; must match the name in the record at `offset`)
   - `offset` — `u32` absolute 0-based file offset to the first byte of that subroutine record

Offsets must be strictly increasing when there are two or more entries. When a record is about to be read, the decoder’s current file position must equal the preamble offset, and the record name must match. Mismatch → `Invalid_Offset`.

Then follow exactly `subroutine_count` subroutine records in preamble order (no second count).

### Subroutine record

1. Signature name (encoded string)
2. Return type — encoded `Value_Type` (`Unit` / `0` for procedures)
3. `parameter_count` — `u32`
4. `parameter_count` type codes (parameter **types** only; no parameter names in v1)
5. `flags` — `u32` (bit 0 = export, bit 1 = entrypoint; other bits preserved like module flags)
6. **Subroutine origin:**
   - `origin_present` — `u8` (`0` / `1`; other → `Invalid_Presence`)
   - when present: filename (encoded string; empty = absent), then `name_span` only (no unit span)
7. `instruction_count` — `u32` (number of instructions, not bytes)
8. Instruction stream — concatenation of encoded instructions (no per-instruction length prefix)

### Instruction stream

| Field | Size |
| --- | --- |
| Opcode | `u16` |
| Immediates | exactly `Immediate_Length(opcode)` bytes |

| Opcode | Word | Immediates | Encoded size |
| --- | ---: | ---: | ---: |
| `No_Operation` | `0x0000` | 0 | 2 bytes |

Unknown opcode word → `Unknown_Opcode` (length is a closed table; the decoder cannot skip).

### End of file

The last instruction of the last subroutine must consume the last byte. Extra bytes → `Trailing_Bytes`. Short read → `Truncated`.

## Ada API

```ada
function Encode (The_Module : Modules.Module) return Encode_Result;
function Decode (Bytes : Byte_Sequence) return Decode_Result;
function Decode (Bytes : Ada.Streams.Stream_Element_Array) return Decode_Result;
function Write (The_Module : Modules.Module; Path : String) return Write_Result;
function Read (Path : String) return Decode_Result;
```

Callers use the `.lir` extension by convention; it is not enforced. `Encode` / `Write` / `Decode` / `Read` apply validation (and format checks on decode). Handle both arms of every result discriminant.

Shared error codes live in `Lovelace.Lir.Errors` (`Internal_Error` first), including `Invalid_Offset` for preamble problems.
