# Lovelace roadmaps

Ordered planning docs. Filenames use `{series}.{nnn}-roadmap-….md`.

## Series 1 — print integer across flavors

| Id | Doc | Summary |
| --- | --- | --- |
| 1.001 | [print integer (WASI)](1.001-roadmap-print-integer-wasi.md) | Flavor `#if`, import/export, multi-unit, synthesized WASI print, HelloPrint E2E |
| 1.002 | [replace synthesized print](1.002-roadmap-replace-synthesized-print.md) | Locals, exprs, boolean, if, loops, `byte`, comments; Lovelace `print` + `PrintUTF8Character` |
| 1.003 | [web print integer](1.003-roadmap-print-integer-web.md) | `--flavor web` console integer print |
| 1.004 | [native print + libaugusta](1.004-roadmap-print-integer-native.md) | wasmtime embed, freestanding `libaugusta` on Linux/Windows/macOS |

## Series 2 — language depth

| Id | Doc | Summary |
| --- | --- | --- |
| 2.001 | [arrays & structures](2.001-roadmap-arrays-structures.md) | Arrays and records |
| 2.002 | [allocation & pointers](2.002-roadmap-allocation-pointers.md) | Alloc/free and pointers |
| 2.003 | [floats & integer types](2.003-roadmap-floats-integer-types.md) | Floating point and remaining integer types |
| 2.004 | [strings](2.004-roadmap-strings.md) | String type and string library |
| 2.005 | [async / await / stream](2.005-roadmap-async-await-stream.md) | WASI-aligned async language features |
| 2.006 | [templates / generics](2.006-roadmap-templates-generics.md) | Generics (module and/or struct/subroutine — TBC) |
| 2.007 | [inheritance / traits / interfaces](2.007-roadmap-inheritance-traits-interfaces.md) | Shared behavior model (details TBC) |
| 2.008 | [overload / override / mangling](2.008-roadmap-overload-override-mangling.md) | Overload, override, name mangling |

## Series 3 — libraries

| Id | Doc | Summary |
| --- | --- | --- |
| 3.001 | [WASI libraries](3.001-roadmap-wasi-libraries.md) | Clock, filesystem, CLI, socket, random |
| 3.002 | [web libraries](3.002-roadmap-web-libraries.md) | WASI-shaped + DOM, storage, WebGL/WebGPU, … |
| 3.003 | [native libraries](3.003-roadmap-native-libraries.md) | WASI-shaped + console, threads, processes, pipes |
| 3.004 | [more Augusta libs](3.004-roadmap-augusta-libraries.md) | crypto, containers, numeric, serdes, HTTP, … |

## Series X — tooling & docs

| Id | Doc | Summary |
| --- | --- | --- |
| X.001 | [package manager](X.001-roadmap-package-manager.md) | Lovelace package manager |
| X.002 | [documentation](X.002-roadmap-documentation.md) | Language / Augusta / contributor docs |

## Series Z — extensibility

| Id | Doc | Summary |
| --- | --- | --- |
| Z.001 | [invoke native code](Z.001-roadmap-invoke-native-code.md) | Call Rust/Ada/C (etc.) libraries from Lovelace |
| Z.002 | [native UI](Z.002-roadmap-native-ui.md) | Native Augusta UI libraries |
