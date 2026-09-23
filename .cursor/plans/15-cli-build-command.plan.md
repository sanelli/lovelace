<!-- d033f602-a549-473d-aee8-aae041ce63cc -->
---
todos:
  - id: "1"
    content: "1. Create GitHub issue with gh issue create (CLI build, LV diagnostics, samples, integration tests); reuse if equivalent open; record 15."
    status: completed
  - id: "2"
    content: "2. Sync main, then gh issue develop 15 --name feature/15-cli-build-command --checkout --base main; verify with gh issue develop --list 15."
    status: completed
  - id: "3"
    content: "3. Rename CreatePlan file to .cursor/plans/15-cli-build-command.plan.md with #15 in the body (do not rewrite a second copy)."
    status: completed
  - id: "4"
    content: "4. Add samples/ barebone empty-body .love for build; document samples-per-feature policy in docs."
    status: completed
  - id: "5"
    content: "5. Update LIR binary and text layouts to persist origins (filename + row/column spans) without bumping Format_Major/Minor from 1.0; tests + docs."
    status: completed
  - id: "6"
    content: "6. Add Lovelace.Compiler.Error_Codes (LV#####) and Diagnostics printer; AUnit format tests."
    status: completed
  - id: "7"
    content: "7. Map tokenizer/parser/IR/backend failures to LV codes; add program-identifier vs .love basename check (LV00009)."
    status: completed
  - id: "8"
    content: "8. Rename procedure Lovelace to Lovelace.Main; depend on lovelace_compiler; implement globals, logo, help, version."
    status: completed
  - id: "9"
    content: "9. Implement lovelace build (flags, .output/obj|bin, incremental mtimes, info lines, emit wasm/wat/wit)."
    status: completed
  - id: "10"
    content: "10. Write docs/cli.md and docs/diagnostics.md; update README/codegen/LIR docs for CLI wiring and origin persistence (still labeled 1.0)."
    status: completed
  - id: "11"
    content: "11. Add lovelace/tests (lovelace_tests) for arguments/helpers used by the CLI."
    status: completed
  - id: "12"
    content: "12. Add lovelace/integration_tests (lovelace_integration_tests): inconclusive without wasmtime; else build sample + run wasm and wat."
    status: completed
  - id: "13"
    content: "13. gnatformat touched Ada; alr build; run common/lir/compiler/lovelace unit tests (integration optional/recorded)."
    status: completed
  - id: "14"
    content: "14. Push (proxy cleared) and open PR with gh pr create."
    status: completed
isProject: false
---
# CLI build command and diagnostics

#15 — [CLI build command, LV diagnostics, samples, and integration tests](https://github.com/sanelli/lovelace/issues/15)

Branch: `feature/15-cli-build-command` (linked; created from `main` via `gh issue develop`).

Plan file: [`.cursor/plans/15-cli-build-command.plan.md`](15-cli-build-command.plan.md).

## Standing rules for this work

### Version discipline (mandatory)

Do **not** change any **version number** unless the user explicitly asks. That includes:

- LIR binary / text `Format_Major` / `Format_Minor` — **stay on 1.0** (no 1.1 bump)
- Alire crate `version` fields in `alire.toml`
- Other schema / product version fields the user did not request to change

**Allowed without a version bump (step 5):** update the **on-disk binary and text layouts** of LIR 1.0 so module/subroutine origins (filepath + row/column spans) round-trip. Header still writes/reads major `1` / minor `0`. Treat this as an in-place layout revision of the still-labeled 1.0 format (repo has no released `.lir` corpus that must stay byte-compatible).

The `version` **command** still prints `0.0.1-alpha.1 @ {hash}` as specified for this feature; that is CLI output text, not a format/crate version bump.

### Samples policy (every new feature)

For **every** new user-facing feature, add at least one `.love` file under [`samples/`](samples/) that exercises that feature.

- Subfolders under `samples/` are allowed when grouping is needed (e.g. multi-file projects or solutions later).
- For **this** CLI build slice: one barebone program with **no instructions** in the body, e.g. `samples/Hello.love`:

```text
program Hello; begin end.
```

Integration tests must build that sample (path under `samples/`), not an ad-hoc-only fixture that never lands in the tree.

---

## Current baseline

- CLI is a no-op [`lovelace/src/lovelace.adb`](lovelace/src/lovelace.adb) with **no** `depends-on` on `lovelace_compiler` ([`lovelace/alire.toml`](lovelace/alire.toml)).
- Pipeline APIs already exist: `Tokenizer.Tokenize`, `Parser.Parse`, `Ir_Generator.Generate`, `Backend.Wasm.Emit_Wasm`, `Backend.Wat.Emit_Wat`, `Lir.Binary.Read` / `Write`.
- LIR origins exist **in memory**; [`.lir` / `.tlir` v1.0 currently drop them](docs/lir.md) — **step 5** updates the layouts (still version 1.0) so they persist.
- Frontend errors use local enums (`Tokenizer_Error_Code`, …), not `LV#####` user codes.
- Naming rule: rename root `procedure Lovelace` → **`Lovelace.Main`** before the CLI depends on `lovelace_common` (via `lovelace_compiler`). Further CLI units are **children of `Lovelace.Main`** only (no other top-level `Lovelace.*` packages in the CLI crate).
- `samples/` may be empty today; this work creates the first barebone sample.

```mermaid
flowchart TD
  cli["Lovelace.Main"]
  love[".love source"]
  lirFile[".output/obj/Name.lir"]
  binDir[".output/bin/Name.wasm|.wat|.wit"]
  tok["Tokenizer"]
  parse["Parser"]
  irgen["Ir_Generator"]
  emit["Backend Wasm/Wat/Wit"]
  cli --> love
  love -->|mtime stale| tok --> parse --> irgen --> lirFile
  lirFile -->|mtime stale| emit --> binDir
```

## Concrete decisions (locked)

| Topic | Choice |
| --- | --- |
| Global args | Only before the command: `--no-logo`, `--no-colour` |
| British spelling | Flag is `--no-colour` (not `--no-color`) |
| Default artifacts | `.wasm` + `.wit` under output `bin/` |
| `--output-format` | `wasm` (default), `wat`, `wasm,wat`, `wat,wasm` (comma set; both mean wasm+wat) |
| `--no-wit` | Do not write `.wit` (still may compute WIT internally when emitting) |
| Output root | Default `.output` in **cwd**; `--output-folder PATH` replaces it (create if missing) |
| Layout | `{root}/obj/{Program}.lir`, `{root}/bin/{Program}.{wasm\|wat\|wit}` |
| Program vs file | Basename of the `.love` path without extension must **exactly** equal the `program` identifier (case-sensitive). Else diagnostic on the identifier span |
| Future no-arg build | Document only; reject missing `.love` for now with a clear error (no `.pjlove` / `.slnlove` yet — note correct extension is `.pjlove`, not `.prjlove`) |
| Logo | Fixed UTF-8 ASCII banner printed to stdout unless `--no-logo` |
| Version string | `0.0.1-alpha.1 @ {short_git_hash}` (build-time hash; `nogit` if unavailable) |
| Colours | ANSI green for `[info]`, red for `[err]` and the `[LVxxxxx]` line; disabled by `--no-colour` |
| Errors | stderr only; info on stdout |
| LIR format | Layout updated to store origins; **`Format_Major`/`Format_Minor` stay 1.0** (step 5) |
| Sample for this feature | `samples/Hello.love` (or equivalent name) — barebone empty body |
| Integration tests | Separate crate `lovelace/integration_tests` (`lovelace_integration_tests`); **not** part of the usual `alr -C */tests run` checklist |
| Wasmtime | `wasmtime run -W component-model=y` plus `--invoke` if required for export `run`; inconclusive if `wasmtime` not on `PATH` |

---

## 1. Create GitHub issue

Done: [#15](https://github.com/sanelli/lovelace/issues/15).

## 2. Linked feature branch from `main`

Done: `feature/15-cli-build-command` (verified with `gh issue develop --list 15`).

## 3. Rename plan file (do not rewrite)

Done: [`.cursor/plans/15-cli-build-command.plan.md`](15-cli-build-command.plan.md).

## 4. Samples: barebone program + policy note

Done: [`samples/Hello.love`](../../samples/Hello.love), [`docs/samples.md`](../../docs/samples.md).

## 5. LIR layouts: persist filename / row / column (still version 1.0)

Done: binary and text codecs persist origins; `Format_Major`/`Format_Minor` remain `1`/`0`; docs and AUnit updated.

## 6. Compiler: unified `LV#####` codes + diagnostic printer

Add in `lovelace_compiler`:

### `Lovelace.Compiler.Error_Codes`

- Stable public codes as an enumeration or constants with canonical text form `LV` + **5 zero-padded digits** (e.g. `LV00001`).
- **One numeric value per distinct error kind** across the compiler (tokenizer, parser, IR, backend, CLI/build semantic checks).
- Suggested initial allocation (extend as needed; document the table in `docs/diagnostics.md`):

| Code | Kind |
| --- | --- |
| `LV00001` | Internal_Error (any stage) |
| `LV00002` | Unrecognized_Symbol |
| `LV00003` | Invalid_Utf_8 |
| `LV00004` | Unexpected_End_Of_Input |
| `LV00005` | Unexpected_Token |
| `LV00006` | Unexpected_Trailing |
| `LV00007` | Unsupported_Type (backend) |
| `LV00008` | Invalid_Module (backend / LIR validate surfaced to user) |
| `LV00009` | Program_Name_Filename_Mismatch |
| `LV00010` | Source_File_Not_Found / IO |
| `LV00011` | Invalid_Command_Line (unknown flag, bad `--output-format`, missing `.love`) |

Keep existing internal enums; map them to `LV#####` at report time (do not break AUnit assertions that check internal enums — add mapping helpers).

### `Lovelace.Compiler.Diagnostics`

- Input: filename, span (row/column from `Source_Position`), source text, `LV` code, description.
- Render **exactly** (stderr):

```text
[err] filename:{row},{column}
{LINE CONTAINING THE ERROR FROM THE SOURCE .love FILE}
{caret line(s) pointing at the column}
[LVxxxxx] {Description of the error}
```

- Caret: spaces/UTF-8-width-safe padding to `Column`, then `^` (and `~~~` under multi-column spans when `Last /= First`).
- Extract the source line using `Line` / `Byte_Index` from the UTF-8 source buffer.
- No colour here — CLI wraps with red when colour enabled.
- Multiple errors: print each block in order; non-zero exit if any error.

Add AUnit coverage in `compiler/tests` for formatting (known source snippet → exact stderr-shaped string).

## 7. Semantic check: program identifier vs filename

After successful `Parse` (or on AST):

- Let `Base` = filename stem of the input path (strip directory; strip final `.love` only).
- Let `Name` = `Ast.Name (Module)`.
- If `Base /= Name`, emit `LV00009` at `Ast.Name_Span`, description naming both strings.
- Applies even when later stages would succeed.

## 8. CLI skeleton: Main, globals, help, version, logo

### Alire / naming

- [`lovelace/alire.toml`](lovelace/alire.toml): `[[depends-on]] lovelace_compiler = "*"` + pin `{ path = "../compiler" }`. Do **not** change the crate `version` field unless the user asks.
- Replace [`lovelace/src/lovelace.adb`](lovelace/src/lovelace.adb) with `lovelace-main.adb` / `procedure Lovelace.Main`; update [`lovelace.gpr`](lovelace/lovelace.gpr) `for Main`.
- Child packages only under `Lovelace.Main.*`, e.g.:
  - `Lovelace.Main.Terminal` — colour-aware `Put_Info`, `Put_Error_Block`, logo
  - `Lovelace.Main.Arguments` — split global opts / command / command opts
  - `Lovelace.Main.Help`
  - `Lovelace.Main.Version`
  - `Lovelace.Main.Build`

### Argument grammar

```text
lovelace [global-options...] <command> [command-parameters...]
```

- Globals (before command only): `--no-logo`, `--no-colour`. Unknown global → `LV00011`.
- If `--no-logo` appears after the command → error (must be before command).
- Commands: `build`, `help`, `version`. Unknown command → error + suggest `help`.

### Logo

- Print banner to stdout at startup unless `--no-logo`.
- Banner is a small fixed UTF-8 ASCII art + `Lovelace` wordmark (invent once; keep stable for tests with `--no-logo`).

### `version`

- Print `0.0.1-alpha.1 @ <hash>` then exit 0.
- Embed hash via Alire `[[actions]]` pre-build writing a tiny generated Ada spec (e.g. `lovelace/src/generated/lovelace-main-git_hash.ads`) from `git rev-parse --short HEAD`, or `nogit` when `.git` missing.

### `help` / `help build`

- No command: summarize globals + commands.
- `lovelace help build`: document `.love` operand, `--no-wit`, `--output-format`, `--output-folder`, incremental behavior, output layout, examples from the request.
- `lovelace help help` / `help version` briefly.

## 9. Implement `lovelace build`

### Command parameters

| Param | Meaning |
| --- | --- |
| first positional | required `.love` path (this slice) |
| `--no-wit` | skip writing `.wit` |
| `--output-format <value>` | see table above |
| `--output-folder <path>` | replace `.output` |

Unknown build flags → `LV00011`. Flags may appear in any order after `build` (examples in the request).

### Steps with `[info]` lines (green `[info]` prefix)

Emit one stdout line per performed step, for example:

- `[info] Reading source …`
- `[info] Tokenizing …` / `Parsing …` / `Generating LIR …` / `Writing …/obj/X.lir`
- `[info] LIR up to date, skipping frontend`
- `[info] Emitting WASM …` / `WAT …` / `WIT …`
- `[info] Artifacts up to date, skipping backend`
- `[info] Build succeeded`

Skip lines for stages not run due to incremental hits; still allowed to log the skip.

### Incremental rules

Using `Ada.Directories.Modification_Time` (or equivalent):

1. Ensure output root, `obj/`, `bin/` exist (`Create_Path`).
2. **LIR:** If `obj/{Name}.lir` exists and `mtime(lir) >= mtime(love)`, do **not** re-tokenize/parse/generate; `Binary.Read` when backend needs it. Else run frontend → `Binary.Write` (1.0 header; origins persisted per step 5).
3. **Note:** program-name check runs only on frontend path; when skipping frontend, trust prior successful build (name already matched when lir was written). Optionally verify `Modules.Name = stem` after read (cheap consistency check).
4. **Each requested artifact** independently: if file missing **or** `mtime(artifact) < mtime(lir)`, regenerate from LIR; else skip.
5. WIT is one file: regenerate if requested and (missing or older than lir). When both wasm and wat refresh, write WIT once.

### Frontend path

1. Read UTF-8 file (IO failure → diagnostic).
2. `Tokenize (Source, Filename)` → on failure print all tokenizer diagnostics via Diagnostics + Terminal (red).
3. `Parse` → same.
4. Program/filename check → `LV00009`.
5. `Ir_Generator.Generate` → map failure to `LV00001`.
6. `Lir.Binary.Write` to `obj/{Name}.lir` (version still 1.0; origins included).

### Backend path

- Resolve `Name` from LIR module name after read/generate.
- `wasm` in format set → `Emit_Wasm`; write `.wasm` bytes; keep `Wit_Text` if wit requested.
- `wat` in format set → `Emit_Wat`; write `.wat`; same WIT string expected.
- Wit only / wit with emit: write `.wit` unless `--no-wit`.
- Backend errors → map to `LV00007` / `LV00008` / `LV00001`; if no source span, print `[err]` with file `Name.love` or lir path and column 1, or a reduced form still using the required shape where possible. Prefer origins from the loaded LIR module when present.

### Exit codes

- `0` on success; non-zero on any error (after printing).

## 10. Documentation

Done: [`docs/cli.md`](../../docs/cli.md), [`docs/diagnostics.md`](../../docs/diagnostics.md); README status + links; codegen / IR generator / LIR / samples cross-links (LIR still labeled 1.0).

New [`docs/cli.md`](docs/cli.md): invocation grammar, globals, `build` / `help` / `version`, colours, logo, output layout, incremental rules, examples, pointer to `samples/Hello.love`.

New [`docs/diagnostics.md`](docs/diagnostics.md): `LV#####` table + exact render format (align with [`.cursor/rules/diagnostics.mdc`](.cursor/rules/diagnostics.mdc) but use `LV` prefix as specified).

Samples policy: short note in `docs/cli.md` or dedicated [`docs/samples.md`](docs/samples.md).

Update [`README.md`](README.md) “not yet a usable compiler” → point at `lovelace build`, samples, and docs.

Update codegen/IR docs for CLI wiring. LIR docs for origin persistence are primarily updated in **step 5**; step 10 only cross-links as needed.

Register nothing new in gnatdoc Projects unless a new host **library** crate appears (CLI is an application; skip unless script already lists it).

## 11. Nested unit tests for CLI helpers

Add [`lovelace/tests`](lovelace/tests) crate `lovelace_tests` (AUnit, pin `..`, depends on `lovelace` or test against packages — prefer testing `Lovelace.Main.Arguments` / format helpers without spawning if possible).

Cover: global vs command flag placement; `--output-format` parsing; help text contains `build`; version string prefix; mismatch detection helper.

Keep these in the **normal** test checklist.

## 12. Integration tests (opt-in)

New crate [`lovelace/integration_tests`](lovelace/integration_tests) / `lovelace_integration_tests`:

- AUnit driver **not** required by workspace default docs checklist; document:

  `alr -C lovelace/integration_tests run`

- Fixture: repo [`samples/Hello.love`](samples/Hello.love) (step 4), built with a dedicated `--output-folder` under a temp dir so the tree stays clean.
- Locate built `lovelace` executable (Alire `../bin/lovelace` or `PATH`).
- If `GNAT.OS_Lib.Locate_Exec_On_Path ("wasmtime")` is null → **`Assert_Inconclusive`** (or AUnit inconclusive mechanism) with message `wasmtime not found`.
- Else:
  1. `lovelace --no-logo build <repo>/samples/Hello.love --output-format wasm,wat --output-folder <temp>` (wit on).
  2. Assert `obj/Hello.lir`, `bin/Hello.wasm`, `bin/Hello.wat`, `bin/Hello.wit` exist under that folder.
  3. Run wasmtime on **both** `.wasm` and `.wat` with component-model enabled (and `--invoke` if needed for `run`).
  4. Success iff both exit 0; else fail with captured stderr.

Do **not** add Wasmtime as an Alire dependency (CLI subprocess only).

## 13. Format, build, run normal tests

Done:

- `gnatformat` on touched Ada under `lovelace/` (and compiler diagnostics when present).
- `alr build` at repo root — success.
- Unit tests: `common/tests` (28), `lir/tests` (17), `compiler/tests` (44), `lovelace/tests` (10) — all passed.
- Integration (optional): `alr -C lovelace/integration_tests run` — passed with Wasmtime present (build `samples/Hello.love` + run `.wasm` / `.wat`).

## 14. Push and open PR

Done: committed docs/CLI tests/integration work; proxy-cleared push; PR opened for #15.

---

## Key files to add/change

| Area | Files |
| --- | --- |
| Samples | [`samples/Hello.love`](samples/Hello.love); optional `docs/samples.md` |
| LIR origins on disk | [`lir/src/lovelace-lir-binary.adb`](lir/src/lovelace-lir-binary.adb), text codec, origins tests, `docs/lir*.md` (**no** major/minor bump) |
| Diagnostics | new `compiler/src/lovelace-compiler-error_codes.ads`, `…-diagnostics.ads/.adb`, compiler tests |
| CLI | `lovelace-main.adb`, `Lovelace.Main.*` children, `alire.toml` depends-on (no version field bump), gpr Main |
| Integration | `lovelace/integration_tests/**` |
| Docs | `docs/cli.md`, `docs/diagnostics.md`, README, codegen/IR CLI notes |
