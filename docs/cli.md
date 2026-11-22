# Lovelace CLI

Crate `lovelace` (`lovelace/lovelace/`) is the host executable. Build it with `alr -C lovelace/lovelace build`; the binary is `lovelace/lovelace/bin/lovelace`.

Related docs: [diagnostics](diagnostics.md), [semantics](semantics.md), [codegen](codegen.md), [samples](samples.md), [LIR](lir.md), [directives](directives.md).

## Invocation

```text
lovelace [global-options...] <command> [command-parameters...]
```

Global options must appear **before** the command. Unknown globals, unknown commands, and build usage mistakes print a plain `[err]` block on stderr (no `LV#####` code) and exit non-zero.

With **no command**, the CLI prints the same text as `lovelace help` on **stderr** and exits non-zero (no `[err]` line).

| Global option | Effect |
| --- | --- |
| `--no-logo` | Do not print the startup banner |
| `--no-colour` | Disable ANSI colours (`[info]` green, `[err]` / `[LVxxxxx]` red) |

British spelling: the flag is `--no-colour`, not `--no-color`.

## Commands

| Command | Role |
| --- | --- |
| `build` | Compile a `.love` file through tokenize → parse → semantics → LIR → WASM/WAT/WIT |
| `help` | General help, or `lovelace help <command>` |
| `version` | Print `0.0.1-alpha.1 @ <short-git-hash>` (`nogit` if unavailable at build time) |

Other commands (`run`, `doc`, `format`, project/solution) are not implemented yet.

### `lovelace version`

Prints one line to stdout. The short git hash is generated at `alr build` by [`scripts/embed-git-hash.ps1`](../scripts/embed-git-hash.ps1) (file is gitignored).

### `lovelace help`

| Form | Output |
| --- | --- |
| `lovelace help` | General usage (stdout) |
| `lovelace help compile` | Build usage and options |
| `lovelace help version` | Version usage |

### `lovelace compile`

```text
lovelace compile <file.love> [options...]
```

A `.love` path is **required** for now. Future builds may accept `.pjlove` / `.slnlove` with no file operand; that is not implemented yet.

| Option | Effect |
| --- | --- |
| `--force` | Rebuild every stage from the `.love` file; ignore incremental mtime skips |
| `--generate-tlir` | Also write `obj/<Unit>.tlir` (textual LIR) next to the binary `.lir`. Not used for incremental mtime decisions. |
| `--no-wit` | Do not write the companion `.wit` file (WIT may still be computed when emitting) |
| `--output-format <fmt>` | `wasm` (default), `wat`, `wasm,wat`, or `wat,wasm` |
| `--output-folder <path>` | Output root (default `.output` in the current working directory) |
| `--flavor <name>` | Active compile-time flavor for `#if` selection: `wasi` (default), `native`, or `web`. See [directives.md](directives.md). |
| `--include-path <dir>` / `-I <dir>` | Extra module search root (repeatable; `-Idir` glued form also accepted). See module search below. |
| `--module-version <ver>` | Fallback module version for every loaded unit when no `@version` attribute and no library `.loveversion` applies (see [Module versions](#module-versions)). Must match `MAJOR.MINOR.BUILD[-preview-name[.preview-number]]`; otherwise a CLI `[err]` block. |
| `--warning-as-errors` | Promote every warning to an error (fail the build) |
| `--no-warnings <ids>` | Suppress warning codes (comma-separated `LV` ids, one argv value). Invalid / non-warning ids → [`LV00030`](diagnostics.md) |

#### Unit name vs filename

The `program` or `module` identifier must **exactly** match the `.love` basename without the extension (case-sensitive). Module names may include dots (`module Foo.Bar;` ↔ `Foo.Bar.love`). Mismatch → [`LV00009`](diagnostics.md).

#### Module search (usings)

Module names from `using` declarations are resolved under an ordered list of search roots:

1. Directory of the root `.love` file
2. Current working directory
3. Each `--include-path` / `-I` directory (CLI order)
4. Augusta stdlib root — **exactly one** slot:
   - `AUGUSTA_HOME` if set
   - else `LOVELACE_HOME/lib/augusta/<product-version>` if `LOVELACE_HOME` is set
   - else `~/.lovelace/lib/augusta/<product-version>`

`<product-version>` is the Lovelace product version without the git hash (e.g. `0.0.1-alpha.1`). That slot is a normal search root: `using augusta.std.io;` looks for `augusta.std.io.love` / `augusta/std/io.love` (and the other mixed forms) **under** the slot. For the in-tree sources, set `AUGUSTA_HOME` to [`augusta/lovelace/`](../augusta/lovelace/) (or pass `-I augusta/lovelace`). Details: [augusta.md](augusta.md).

For module `a.b.c`, every mixed slash/dot relative form is a candidate (`a/b/c.love`, `a/b.c.love`, `a.b/c.love`, `a.b.c.love`). Exactly one existing file must match; zero → [`LV00016`](diagnostics.md); two or more → [`LV00020`](diagnostics.md). See [ir-generator.md](ir-generator.md).

#### Module versions

Each loaded unit gets one version, recorded in the `.lir` module header (and per dependency) and used for the guest package identity (`lovelace:<segments>@<version>` in WIT/WAT/WASM; see [codegen.md](codegen.md)). Priority, highest first:

1. The unit's own `@version("…")` attribute (after its `using` declarations; see [compilation-unit-grammar.md](compilation-unit-grammar.md))
2. A `.loveversion` file in the library search root that contains the unit's `.love` file (the longest matching root; the file holds exactly `@version("…")`)
3. `--module-version <ver>`
4. The default, `0.0.1`

Invalid versions in source or in `.loveversion` → [`LV00034`](diagnostics.md). The in-tree Augusta library pins its version with [`augusta/lovelace/.loveversion`](../augusta/lovelace/.loveversion).

#### Output layout

Under the output root:

```text
obj/<Unit>.lir
obj/<Unit>.tlir    # only with --generate-tlir
bin/<Unit>.wasm    # if format includes wasm
bin/<Unit>.wat     # if format includes wat
bin/<Unit>.wit     # unless --no-wit
```

The `.lir` file is LIR **1.0** (origins included; see [lir-binary.md](lir-binary.md)). With `--generate-tlir`, the CLI also writes the companion textual form ([lir-text.md](lir-text.md)). Backends: [codegen.md](codegen.md).

#### Incremental builds

| Stage | Skip when (unless `--force`) |
| --- | --- |
| Frontend (tokenize / parse / IR / write `.lir`) | `mtime(.lir) >= mtime(.love)` |
| Backend (wasm / wat / wit) | each artifact’s mtime is `>=` mtime of `.lir` |

`.tlir` is **never** used for skip decisions (presence or mtime). When `--generate-tlir` is set, textual LIR is rewritten whenever the in-memory LIR module is available (including when the frontend was skipped and `.lir` was only re-read).

Skipped stages log an `[info]` line (for example `LIR up to date, skipping frontend`).

#### Info and errors

- `[info] …` on **stdout** (green when colour is on)
- Located compiler diagnostics (`[err]` / `[warning]`) and CLI `[err]` blocks on **stderr**
- Exit status `0` on success (warnings alone do not fail); non-zero after any remaining **error** (including promoted warnings)

#### Examples

```text
lovelace compile samples/program/Hello.love
lovelace compile samples/module/Empty.love
lovelace compile samples/module/Foo.Bar.love
lovelace compile samples/directives/FlavorSelect.love
lovelace compile samples/directives/FlavorSelect.love --flavor native
lovelace --no-logo build samples/program/Hello.love --force
lovelace compile samples/program/Hello.love --generate-tlir
lovelace compile samples/program/Hello.love --output-format wasm,wat --output-folder /tmp/out
lovelace compile samples/program/Hello.love --no-wit --output-format wat
lovelace compile samples/variables/Variables.love --warning-as-errors
lovelace compile samples/variables/Variables.love --no-warnings LV00028,LV00029,LV00032
```

Samples: [`samples/program/Hello.love`](../samples/program/Hello.love) (program), [`samples/module/Empty.love`](../samples/module/Empty.love) and [`samples/module/Foo.Bar.love`](../samples/module/Foo.Bar.love) (modules), [`samples/directives/FlavorSelect.love`](../samples/directives/FlavorSelect.love) (flavor `#if`). Policy: [samples.md](samples.md).

#### Running the artifact

With an entrypoint, plain Wasmtime finds `wasi:cli/run@0.3.0`:

```text
wasmtime run -Sp3 -W component-model-async=y .output/bin/Hello.wasm
wasmtime run -Sp3 -W component-model-async=y .output/bin/Hello.wat
```

Empty modules have no entrypoint; build them for artifacts only (do not expect `wasmtime run` to succeed).

See [codegen.md](codegen.md) for export naming and kebab-case rules.

## Tests

From the repository root, build and run the nested AUnit crates with:

```powershell
pwsh -NoProfile -File scripts/run-tests.ps1
pwsh -NoProfile -File scripts/run-tests.ps1 -SkipIntegration
pwsh -NoProfile -File scripts/run-tests.ps1 -SkipUnit
```

By default the script runs workspace `alr build`, all unit crates below, then the integration crate. `-SkipUnit` skips the unit crates; `-SkipIntegration` skips `lovelace/lovelace/integration_tests`. Both may be combined.

| Crate | Command | Role |
| --- | --- | --- |
| `lovelace/common/tests` | `alr -C lovelace/common/tests run` | Shared host library unit tests |
| `lovelace/lir/tests` | `alr -C lovelace/lir/tests run` | LIR types / codecs unit tests |
| `lovelace/compiler/tests` | `alr -C lovelace/compiler/tests run` | Compiler frontend / backend unit tests |
| `lovelace/lovelace/tests` (`lovelace_tests`) | `alr -C lovelace/lovelace/tests run` | Unit tests for argument parsing, output-format, help, version, basename |
| `lovelace/lovelace/integration_tests` (`lovelace_integration_tests`) | `alr -C lovelace/lovelace/integration_tests run` | Optional: build `samples/program/Hello.love` into `.tests/integration-tests/` and run Wasmtime on `.wasm` / `.wat` (prints `INCONCLUSIVE: wasmtime not found` and passes if Wasmtime is missing); also builds module samples under `samples/module/` |

Integration tests are **not** part of the default unit-test checklist; use `-SkipIntegration` when you only want units, or `-SkipUnit` when you only want integration.

## Logo

Unless `--no-logo`, startup prints a FIGlet-style **Lovelace** banner and `Lovelace compiler toolchain <version>` on stdout.
