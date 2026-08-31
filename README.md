# Lovelace

Lovelace is a new programming language in the Pascal / Ada / Delphi family, together with a compiler and toolchain written in **Ada**. The compiler turns Lovelace source into [WebAssembly](https://webassembly.org/) **components** (`.wasm`), optional WAT (WebAssembly Text), and companion WIT interface files. Programs can be built and run from a `dotnet`-style CLI; execution uses a JIT embedder of the Wasmtime C API.

The standard library is **Augusta** (Ada Lovelace’s given name). Packages are managed by **Hypatia**. Documentation is produced by **Alexandria**.

This repository is in early design. Implementation proceeds piece by piece.

## A love letter

This project is a love letter to two mathematicians.

**[Ada Lovelace](https://en.wikipedia.org/wiki/Ada_Lovelace)** (Augusta Ada King, Countess of Lovelace) was a pioneer of writing programs: her notes on Babbage’s Analytical Engine are among the first published algorithms intended for a machine. The language, its IR, and the project/solution tooling are named for her. The standard library is **Augusta**, her given name. The implementation language is Ada — my favourite language — which was itself named in her honour.

**[Hypatia of Alexandria](https://en.wikipedia.org/wiki/Hypatia)** was a mathematician, astronomer, and philosopher. She taught in Alexandria and was murdered in 415 by a mob of Christian zealots. The package manager is named **Hypatia** for her. Documentation lives under **Alexandria**: her city, and a nod to the [Library of Alexandria](https://en.wikipedia.org/wiki/Library_of_Alexandria).

I named the pieces of this system after them:

| Name | After | In this project |
| --- | --- | --- |
| **Lovelace**, **LIR** (Lovelace IR), `.love` / `.pjlove` / `.slnlove` / `.pkglove` | Ada Lovelace | Language, intermediate representation, sources, and project/solution/package files |
| **Augusta** | Augusta — Ada Lovelace’s given name | Standard library (`.love` plus the only dynamic/shared native library) |
| **Ada** (the host language) | Ada Lovelace | All of the compiler and toolchain source |
| **Hypatia** | Hypatia of Alexandria | Package manager (local and git dependencies) |
| **Alexandria** | Alexandria — Hypatia’s city and the Great Library | Documentation: doc-comments, `lovelace doc`, and the `docs/` tree |

## High-level components

The toolchain is one Ada **executable** (`lovelace`) plus **static** libraries it links. The **only** dynamic/shared library is Augusta’s native backing. Each top-level Ada directory is its own Alire crate.

| Component | Role |
| --- | --- |
| **`compiler/`** | Static library: frontend, LIR lowering, WASM / WAT / WIT backend |
| **`lir/`** | Static library: Lovelace IR analysis and optimization |
| **`common/`** | Static library: shared host code |
| **`jit/`** | Static library: JIT runtime; binds and links the Wasmtime C library |
| **`lovelace/`** | Executable CLI (`lovelace build`, `run`, `doc`, project and solution commands) |
| **`tooling/`** | Static library: `.pjlove`, `.slnlove`, and `.pkglove` formats and behaviour |
| **`hypatia/`** | Static library: Hypatia package manager (folder or git; a package must include `.pkglove`) |
| **`alexandria/`** | Static library: parse comments / doc-comments and generate Markdown (and SVG when useful) |
| **`augusta/`** | Standard library (`.love` plus the **only** dynamic native library); flavors `native`, `wasi`, and `web` |
| **`samples/`** | Lovelace samples used for testing |
| **`docs/`** | Human documentation (CLI, grammar, HOW TOs) |
| **`scripts/`** | Scripts to compile and run samples |

Pipeline: **source → frontend → LIR (analysis / opts) → backend → WebAssembly component + WIT**. The JIT loads that component; it does not parse Lovelace.

## Status

Not yet a usable compiler. Design and conventions live in `.cursor/rules/`. Contributions should follow those rules (Alire, strict Ada, AUnit tests, no extra third-party libraries except the allowed Wasmtime C, libgit2, and AUnit bindings).

Build the workspace from the repository root with `alr build`, or build or run the CLI crate alone with `alr -C lovelace build` or `alr -C lovelace run`.

### macOS linking (`-lSystem`)

On some Mac hosts, linking the host toolchain with Alire’s GNAT fails at the final link step with:

```text
ld: library not found for -lSystem
```

Ada compilation still succeeds; the linker cannot find `libSystem` in the SDK search path. Prepend the macOS SDK `usr/lib` directory to `LIBRARY_PATH`, then run `alr build` as usual:

```bash
export LIBRARY_PATH="$(xcrun --show-sdk-path)/usr/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
alr build
```

In PowerShell:

```powershell
$env:LIBRARY_PATH = "$(xcrun --show-sdk-path)/usr/lib" + $(if ($env:LIBRARY_PATH) { ":$env:LIBRARY_PATH" } else { '' })
alr build
```

You need Xcode Command Line Tools (or Xcode) installed so `xcrun --show-sdk-path` returns a valid SDK.
