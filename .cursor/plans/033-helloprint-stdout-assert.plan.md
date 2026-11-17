---
name: HelloPrint stdout assert
overview: Close the remaining gap in roadmap macro-step 9 — capture wasmtime stdout for HelloPrint and assert it is exactly `42` (no trailing newline).
todos:
  - id: "1"
    content: "1. Create GitHub issue with gh issue create (HelloPrint stdout assert); reuse if equivalent open issue exists; record <n>."
    status: completed
  - id: "2"
    content: "2. Sync main, then gh issue develop <n> --name feature/<n>-helloprint-stdout-assert --checkout --base main. Verify with gh issue develop --list <n>."
    status: completed
  - id: "3"
    content: "3. Save this plan as .cursor/plans/<nnn>-helloprint-stdout-assert.plan.md with #<n> in the body (rename from 033 if issue number differs)."
    status: completed
  - id: "4"
    content: "4. Extend integration Support: optional Expected_Stdout on Run_Entrypoint_Artifact / Run_Unit_Entrypoint; Spawn_Capturing_Stdout; Read_Exact_File (byte-exact, not Get_Line); gnatformat."
    status: completed
  - id: "5"
    content: "5. Wire HelloPrint test to Expected_Stdout => \"42\"; update Hello_Build ads comment; leave other entrypoint runs exit-code-only."
    status: completed
  - id: "6"
    content: "6. Run lovelace/integration_tests (AUGUSTA_HOME set); confirm HelloPrint OK and no regressions."
    status: completed
  - id: "7"
    content: "7. Push (proxy env cleared) and open a PR with gh pr create."
    status: pending
isProject: false
---

# Integration: assert HelloPrint wasmtime stdout is 42

#33 — [Integration: assert HelloPrint wasmtime stdout is 42](https://github.com/sanelli/lovelace/issues/33)

Branch: `feature/33-helloprint-stdout-assert` (linked to #33; created from `main` via `gh issue develop`).

Plan file: [`.cursor/plans/033-helloprint-stdout-assert.plan.md`](033-helloprint-stdout-assert.plan.md).

Roadmap: [docs/roadmap/1.001-roadmap-print-integer-wasi.md](../../docs/roadmap/1.001-roadmap-print-integer-wasi.md) § Macro step 9 (remaining stdout content check after #31 / PR #32).

Prerequisite: native WASI print + Augusta.io ([#31](https://github.com/sanelli/lovelace/issues/31), [PR #32](https://github.com/sanelli/lovelace/pull/32)).

**How to execute:** one numbered step per invocation (or an explicit consecutive range). Do not skip the envelope (1–3) or the closing tests/PR. After each Ada edit step, run `alr exec -- gnatformat` on touched files and build/run the integration test crate before moving on.

## Locked decisions

- **Exact stdout:** assert guest stdout bytes equal `"42"` with **no** trailing newline (matches documented print policy).
- **Both artifacts:** when `Expected_Stdout` is non-empty, check **both** `.wasm` and `.wat` wasmtime runs.
- **Opt-in only:** empty `Expected_Stdout` (default) keeps prior exit-code-only behavior for Hello / ImportDecl / Caller.
- **Exact read:** do **not** use `Read_Text_File` / `Get_Line` for the assert — those can inject newlines. Use `Ada.Streams.Stream_IO` (or equivalent) for a byte-exact read.
- **Capture path:** write wasmtime stdout to a sibling temp file (e.g. `Path & ".stdout"`); leave stderr separate so `[err]` diagnostics still surface.

## Scope

| In | Out |
| --- | --- |
| `Support.Run_Entrypoint_Artifact` / `Run_Unit_Entrypoint` + capture helpers | Changing print policy / backend synthesis |
| HelloPrint `Expected_Stdout => "42"` | Asserting stdout for other samples unless requested |
| Integration-test-only Ada changes | Roadmap prose edits (optional; step 9 already largely documented) |

## Steps

### 1–3. Envelope

Create #33, branch `feature/33-helloprint-stdout-assert` from `main`, save this plan under `.cursor/plans/033-helloprint-stdout-assert.plan.md`.

### 4. Support helpers

Files:

- `lovelace/integration_tests/src/lovelace-main-integration_tests-support.ads`
- `lovelace/integration_tests/src/lovelace-main-integration_tests-support.adb`

Add optional `Expected_Stdout : String := ""` to:

- `Run_Entrypoint_Artifact`
- `Run_Unit_Entrypoint`

When non-empty:

1. Spawn wasmtime with stdout redirected to a capture file (`Spawn_Capturing_Stdout`).
2. Read capture with `Read_Exact_File`.
3. Assert `Actual = Expected_Stdout` (failure message includes both strings).

When empty: keep `Spawn_Discarding_Stdout` / exit-code-only path.

Nested helpers must stay alphabetically ordered for `-gnatyo` (`Spawn_Capturing_Stdout` before `Spawn_Discarding_Stdout`; `Read_Exact_File` before `Read_Text_File`).

### 5. HelloPrint wiring

Files:

- `lovelace/integration_tests/src/lovelace-main-integration_tests-hello_build.adb`
- `lovelace/integration_tests/src/lovelace-main-integration_tests-hello_build.ads`

Pass `Expected_Stdout => "42"` from `Test_Hello_Print_Build_Validate_And_Run` into `Helpers.Run_Unit_Entrypoint`. Update the procedure comment to mention the stdout assert.

### 6. Tests

```bash
alr -C lovelace build
AUGUSTA_HOME="$PWD/augusta" alr -C lovelace/integration_tests run
# or: pwsh scripts/run-tests.ps1 -SkipUnit
```

Expect `build: validate and run program HelloPrint [OK]` and no other integration failures.

### 7. Push / PR

Push the branch and open a PR targeting `main` that closes #33.

## Outcome (reference)

Implemented and verified on `feature/33-helloprint-stdout-assert`:

- Optional exact stdout assert on entrypoint run helpers.
- HelloPrint expects `"42"`.
- Full `lovelace/integration_tests` suite green with `AUGUSTA_HOME` set.
