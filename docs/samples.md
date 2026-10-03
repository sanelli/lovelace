# Samples

The [`samples/`](../samples/) tree holds small `.love` programs and modules used to exercise features end-to-end (CLI builds, integration tests, and manual checks). Build them with [`lovelace build`](cli.md).

Integration tests (`lovelace/integration_tests`) require `wasm-tools` and `wasmtime` on `PATH`, build these samples (suppressing `[info]` stdout), validate every `.wasm`/`.wat`, and **run** only program/entrypoint artifacts. See the integration-tests Cursor rule.

## Policy

For **every** new user-facing feature, add at least one `.love` file under `samples/<feature>/` that exercises that feature.

- **Never** place a `.love` file directly in `samples/` (always use a feature subfolder).
- Prefer a focused unit that demonstrates the feature with the smallest valid surface.
- Group samples by main feature (`program/`, `module/`, …); reuse an existing folder when the sample belongs there.
- Keep sample `program` / `module` identifiers identical to the `.love` basename (excluding the extension; dots allowed for modules).

## Current samples

| Path | Feature |
| --- | --- |
| [`samples/program/Hello.love`](../samples/program/Hello.love) | Minimal empty-body program for `lovelace build` and wasmtime integration |
| [`samples/module/Empty.love`](../samples/module/Empty.love) | Minimal empty module (`module Empty; end.`) |
| [`samples/module/Foo.Bar.love`](../samples/module/Foo.Bar.love) | Dotted module name (`module Foo.Bar; end.`) |
| [`samples/module/Procedures.love`](../samples/module/Procedures.love) | Module procedures with Ada-style typed parameters |
