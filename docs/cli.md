# Lovelace CLI

Crate `lovelace` (`lovelace/`) is the host executable. Build it with `alr -C lovelace build`; the binary is `lovelace/bin/lovelace`.

Related docs: [diagnostics](diagnostics.md), [codegen](codegen.md), [samples](samples.md), [LIR](lir.md).

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
| `build` | Compile a `.love` file through tokenize → parse → LIR → WASM/WAT/WIT |
| `help` | General help, or `lovelace help <command>` |
| `version` | Print `0.0.1-alpha.1 @ <short-git-hash>` (`nogit` if unavailable at build time) |

Other commands (`run`, `doc`, `format`, project/solution) are not implemented yet.

### `lovelace version`

Prints one line to stdout. The short git hash is generated at `alr build` by [`scripts/embed-git-hash.ps1`](../scripts/embed-git-hash.ps1) (file is gitignored).

### `lovelace help`

| Form | Output |
| --- | --- |
| `lovelace help` | General usage (stdout) |
| `lovelace help build` | Build usage and options |
| `lovelace help version` | Version usage |

### `lovelace build`

```text
lovelace build <file.love> [options...]
```

A `.love` path is **required** for now. Future builds may accept `.pjlove` / `.slnlove` with no file operand; that is not implemented yet.

| Option | Effect |
| --- | --- |
| `--force` | Rebuild every stage from the `.love` file; ignore incremental mtime skips |
| `--no-wit` | Do not write the companion `.wit` file (WIT may still be computed when emitting) |
| `--output-format <fmt>` | `wasm` (default), `wat`, `wasm,wat`, or `wat,wasm` |
| `--output-folder <path>` | Output root (default `.output` in the current working directory) |

#### Program name vs filename

The `program` identifier must **exactly** match the `.love` basename without the extension (case-sensitive). Mismatch → [`LV00009`](diagnostics.md).

#### Output layout

Under the output root:

```text
obj/<Program>.lir
bin/<Program>.wasm    # if format includes wasm
bin/<Program>.wat     # if format includes wat
bin/<Program>.wit     # unless --no-wit
```

The `.lir` file is LIR **1.0** (origins included; see [lir-binary.md](lir-binary.md)). Backends: [codegen.md](codegen.md).

#### Incremental builds

| Stage | Skip when (unless `--force`) |
| --- | --- |
| Frontend (tokenize / parse / IR / write `.lir`) | `mtime(.lir) >= mtime(.love)` |
| Backend (wasm / wat / wit) | each artifact’s mtime is `>=` mtime of `.lir` |

Skipped stages log an `[info]` line (for example `LIR up to date, skipping frontend`).

#### Info and errors

- `[info] …` on **stdout** (green when colour is on)
- Located compiler diagnostics and CLI `[err]` blocks on **stderr**
- Exit status `0` on success; non-zero after any error

#### Examples

```text
lovelace build samples/Hello.love
lovelace --no-logo build samples/Hello.love --force
lovelace build samples/Hello.love --output-format wasm,wat --output-folder /tmp/out
lovelace build samples/Hello.love --no-wit --output-format wat
```

Sample program: [`samples/Hello.love`](../samples/Hello.love). Policy for adding samples: [samples.md](samples.md).

#### Running the artifact

With an entrypoint, plain Wasmtime finds `wasi:cli/run@0.3.0`:

```text
wasmtime run -Sp3 -W component-model-async=y .output/bin/Hello.wasm
wasmtime run -Sp3 -W component-model-async=y .output/bin/Hello.wat
```

See [codegen.md](codegen.md) for export naming and kebab-case rules.

## Tests

From the repository root, build and run the nested AUnit crates with:

```powershell
pwsh -NoProfile -File scripts/run-tests.ps1
pwsh -NoProfile -File scripts/run-tests.ps1 -SkipIntegration
pwsh -NoProfile -File scripts/run-tests.ps1 -SkipUnit
```

By default the script runs workspace `alr build`, all unit crates below, then the integration crate. `-SkipUnit` skips the unit crates; `-SkipIntegration` skips `lovelace/integration_tests`. Both may be combined.

| Crate | Command | Role |
| --- | --- | --- |
| `common/tests` | `alr -C common/tests run` | Shared host library unit tests |
| `lir/tests` | `alr -C lir/tests run` | LIR types / codecs unit tests |
| `compiler/tests` | `alr -C compiler/tests run` | Compiler frontend / backend unit tests |
| `lovelace/tests` (`lovelace_tests`) | `alr -C lovelace/tests run` | Unit tests for argument parsing, output-format, help, version, basename |
| `lovelace/integration_tests` (`lovelace_integration_tests`) | `alr -C lovelace/integration_tests run` | Optional: build `samples/Hello.love` into `.tests/integration-tests/` and run Wasmtime on `.wasm` / `.wat` (prints `INCONCLUSIVE: wasmtime not found` and passes if Wasmtime is missing) |

Integration tests are **not** part of the default unit-test checklist; use `-SkipIntegration` when you only want units, or `-SkipUnit` when you only want integration.

## Logo

Unless `--no-logo`, startup prints a FIGlet-style **Lovelace** banner and `Lovelace compiler toolchain <version>` on stdout.
