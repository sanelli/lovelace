# Lovelace roadmaps

Ordered planning docs. Filenames use `{series}.{nnn}-roadmap-….md`.

## Series 1 — print integer across flavors

| Id | Doc | Summary |
| --- | --- | --- |
| 1.001 | [print integer (WASI)](1.001-roadmap-print-integer-wasi.md) | Flavor `#if`, import/export, multi-unit, synthesized WASI print, HelloPrint E2E |
| 1.002 | [replace synthesized print](1.002-roadmap-replace-synthesized-print.md) | Comments, `@intrinsic`/`@native`, literals, boolean, `:=` + **typechecker**/`Lovelace_Type`, exprs, ops, if, loop, `unsigned integer<8>` + minimal casts, Lovelace `print` |
| 1.003 | [web print integer](1.003-roadmap-print-integer-web.md) | `--flavor web` console integer print |
| 1.004 | [native print + libaugusta](1.004-roadmap-print-integer-native.md) | wasmtime embed, freestanding `libaugusta` on Linux/Windows/macOS |

## Series 2 — language depth

| Id | Doc | Summary |
| --- | --- | --- |
| 2.001 | [more language features](2.001-roadmap-more-language-features.md) | More loops, switch/case, expression blocks, import as / unqualified use, remaining `integer<N>`/`float<N>`, cast matrix, … |
| 2.002 | [arrays & type records](2.002-roadmap-arrays-type-records.md) | Arrays, type records; `PrintUTF8String(unsigned integer<8>[])` stream shim |
| 2.003 | [allocation, pointers, modes](2.003-roadmap-allocation-pointers.md) | Alloc/free, pointers, `in`/`out`/`inout`, multi-return |
| 2.004 | [residual numerics](2.004-roadmap-floats-integer-types.md) | Soft-float / decimal / leftover numeric polish (types+casts → 2.001) |
| 2.005 | [strings](2.005-roadmap-strings.md) | String type/library; number ↔ string conversion |
| 2.006 | [async / await / stream](2.006-roadmap-async-await-stream.md) | WASI-aligned async language features |
| 2.007 | [templates / generics](2.007-roadmap-templates-generics.md) | Generics (module and/or type record/subroutine — TBC) |
| 2.008 | [inheritance / traits / interfaces](2.008-roadmap-inheritance-traits-interfaces.md) | Shared behavior model (details TBC) |
| 2.009 | [overload / override / mangling](2.009-roadmap-overload-override-mangling.md) | Overload, override, mangling, variance |
| 2.010 | [unions & enums](2.010-roadmap-unions-enums.md) | C/Rust/C#/Ada unions; C/Java-style enums |
| 2.011 | [functional features](2.011-roadmap-functional-features.md) | Functional-language features (set TBC) |
| 2.012 | [advanced syntax & attributes](2.012-roadmap-advanced-syntax-attributes.md) | Comprehensions, init sugar, attributes |
| 2.013 | [generic specializations](2.013-roadmap-generic-specializations.md) | Per-`T` specialized generic implementations |
| 2.014 | [const & immutable](2.014-roadmap-const-immutable.md) | Const bindings vs immutable contents (C++/Rust mix) |
| 2.015 | [program params & return](2.015-roadmap-program-parameters-return.md) | Program parameters like a subroutine; numeric program return |

## Series 3 — libraries

| Id | Doc | Summary |
| --- | --- | --- |
| 3.001 | [WASI libraries](3.001-roadmap-wasi-libraries.md) | Clock, filesystem, CLI, socket, random |
| 3.002 | [web libraries](3.002-roadmap-web-libraries.md) | WASI-shaped + DOM, storage, WebGL/WebGPU, … |
| 3.003 | [native libraries](3.003-roadmap-native-libraries.md) | WASI-shaped + console, threads, processes, pipes |
| 3.004 | [more Augusta libs](3.004-roadmap-augusta-libraries.md) | crypto, containers, numeric, serdes, HTTP, … |

## Series X — compiler analyses, opts, generators

| Id | Doc | Summary |
| --- | --- | --- |
| X.001 | [analyzers](X.001-roadmap-analyzers.md) | Dataflow, liveness, etc. |
| X.002 | [optimizers](X.002-roadmap-optimizers.md) | Const/copy prop, CSE, DCE, loops, SSA, tail recursion |
| X.003 | [source generators](X.003-roadmap-source-generators.md) | User-defined Lovelace source generators |

## Series Y — tooling & docs

| Id | Doc | Summary |
| --- | --- | --- |
| Y.001 | [package manager](Y.001-roadmap-package-manager.md) | Lovelace package manager |
| Y.002 | [documentation](Y.002-roadmap-documentation.md) | Language / Augusta / contributor docs |

## Series Z — extensibility

| Id | Doc | Summary |
| --- | --- | --- |
| Z.001 | [invoke native code](Z.001-roadmap-invoke-native-code.md) | Call Rust/Ada/C (etc.) libraries from Lovelace |
| Z.002 | [native UI](Z.002-roadmap-native-ui.md) | Native Augusta UI libraries |
