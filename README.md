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

Build the workspace from the repository root with `alr build`, or build or run the CLI crate alone with `alr -C lovelace build` or `alr -C lovelace run`. Generate host Ada API HTML with GNATdoc via `pwsh scripts/gnatdoc.ps1` (see [docs/gnatdoc.md](docs/gnatdoc.md)).

### Development tools

Install these Alire crates once (in addition to the GNAT toolchain Alire selects for the workspace):

```bash
alr install libadalang_tools
alr install gnatdoc
```

### Ada code formatting

The formatter executable is **`gnatformat`** (from `libadalang_tools`; see **Development tools** above). Run it through Alire so it uses the same environment as `alr build`.

Example (format one file in place, 120-column width):

```powershell
alr exec -- gnatformat -w 120 -P common/lovelace_common.gpr common/src/lovelace-common-utf_8.adb
```

### macOS setup

You need Xcode Command Line Tools (or Xcode) installed so `xcrun` returns a valid SDK.

On some Mac hosts, Alire’s GNAT toolchain needs two environment variables set before `alr build`:

1. **`LIBRARY_PATH`** — the linker cannot find `libSystem` without the SDK `usr/lib` directory on the search path (`ld: library not found for -lSystem`).
2. **`MACOSX_DEPLOYMENT_TARGET`** — should match the active SDK version so clang does not warn about overriding the deployment target (`overriding deployment version from '16.0' to '26.0'`).

Add these to your shell profile so every new terminal is ready to build.

**zsh** (`~/.zshrc`):

```bash
export LIBRARY_PATH="$(xcrun --show-sdk-path)/usr/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
export MACOSX_DEPLOYMENT_TARGET="$(xcrun --show-sdk-version)"
```

Reload: `source ~/.zshrc`

**PowerShell** (`$PROFILE`, e.g. `~/.config/powershell/Microsoft.PowerShell_profile.ps1`):

```powershell
$sdkLib = "$(xcrun --show-sdk-path)/usr/lib"
if ($env:LIBRARY_PATH) {
    $env:LIBRARY_PATH = "${sdkLib}:$env:LIBRARY_PATH"
} else {
    $env:LIBRARY_PATH = $sdkLib
}
$env:MACOSX_DEPLOYMENT_TARGET = "$(xcrun --show-sdk-version)"
```

Reload: `. $PROFILE`

One-off for a single session (bash/zsh):

```bash
export LIBRARY_PATH="$(xcrun --show-sdk-path)/usr/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
export MACOSX_DEPLOYMENT_TARGET="$(xcrun --show-sdk-version)"
alr build
```

One-off in PowerShell:

```powershell
$sdkLib = "$(xcrun --show-sdk-path)/usr/lib"
if ($env:LIBRARY_PATH) {
    $env:LIBRARY_PATH = "${sdkLib}:$env:LIBRARY_PATH"
} else {
    $env:LIBRARY_PATH = $sdkLib
}
$env:MACOSX_DEPLOYMENT_TARGET = "$(xcrun --show-sdk-version)"
alr build
```

### JetBrains Rider (macOS)

Rider has no built-in Ada support. Use the [Ada Language Server](https://github.com/AdaCore/ada_language_server) (ALS) via the [LSP4IJ](https://plugins.jetbrains.com/plugin/23257-lsp4ij) plugin, plus a TextMate bundle for syntax coloring.

1. **Download ALS** — get a release from [AdaCore/ada_language_server](https://github.com/AdaCore/ada_language_server/releases), unpack it somewhere permanent (for example `~/opt/ada_language_server/`), and note the full path to the `ada_language_server` executable.

2. **Put `alr` on the PATH for GUI apps** — Rider does not read your shell profile. Register Alire’s `bin` directory system-wide so ALS can invoke `gprbuild` and related tools:

   ```bash
   echo /path/to/alire/bin | sudo tee /etc/paths.d/alire
   ```

   Replace `/path/to/alire/bin` with the directory that contains your `alr` binary (often `~/.local/share/alire/bin` or similar). **Log out and back in** (or restart the Mac) so `/etc/paths.d` entries take effect.

3. **Install LSP4IJ** — in Rider, open **Settings → Plugins**, search for **LSP4IJ**, install it, and restart Rider.

4. **Configure ALS** — open any `.adb` or `.ads` file. When Rider prompts to set up the Ada language server, choose the full path to the `ada_language_server` binary from step 1.

5. **Better syntax coloring** — clone the TextMate Ada bundle and register it in Rider:

   ```bash
   git clone https://github.com/textmate/ada.tmbundle.git ~/opt/ada.tmbundle
   ```

   Then **Settings → Editor → TextMate Bundles**, click **+**, and select the cloned folder. Keyword and comment colors follow your color scheme under **Editor → Color Scheme → Language Defaults** (and **Language Server** for semantic tokens from ALS).

6. **Hiding build artifacts** — Alire and GNAT output directories (`alire/`, `obj/`, `bin/`, `config/`, `lib/`) clutter the Project view. Rider’s **Settings → Editor → File Types → Ignored Files and Folders** or **Mark Directory as → Excluded** may not fully hide them in every view; this is still an open annoyance. If you find a reliable approach, please document it here.
