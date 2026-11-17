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
| [`samples/import/ImportDecl.love`](../samples/import/ImportDecl.love) | File-leading `import ImportLib;` before an empty-body program (resolves same-folder module) |
| [`samples/import/ImportLib.love`](../samples/import/ImportLib.love) | Empty module dependency for `ImportDecl` |
| [`samples/module/Empty.love`](../samples/module/Empty.love) | Minimal empty module (`module Empty; end.`) |
| [`samples/module/Foo.Bar.love`](../samples/module/Foo.Bar.love) | Dotted module name (`module Foo.Bar; end.`) |
| [`samples/module/Procedures.love`](../samples/module/Procedures.love) | Module procedures with Ada-style typed parameters |
| [`samples/module/ExportProcedures.love`](../samples/module/ExportProcedures.love) | `export procedure` (Lovelace visibility) plus a non-exported helper |
| [`samples/native/NativePrint.love`](../samples/native/NativePrint.love) | `export native("wasi", "native-print-integer") procedure print(…);` (backend synthesizes WASI 0.3 stdout write) |
| [`samples/io/HelloPrint.love`](../samples/io/HelloPrint.love) | `import augusta.std.io;` then `augusta.std.io.print(42);` (needs `AUGUSTA_HOME=augusta` or `-I augusta`) |
| [`samples/directives/FlavorSelect.love`](../samples/directives/FlavorSelect.love) | Flavor `#if` / `#elsif` / `#else` / `#end` (default `--flavor wasi` keeps `WasiOnly`) |
| [`samples/calls/SameModuleCall.love`](../samples/calls/SameModuleCall.love) | Same-unit qualified call with integer literal (`SameModuleCall.Sink(42)`) |
| [`samples/resolve/Caller.love`](../samples/resolve/Caller.love) | Multi-unit program: `import Lib` / `import pkg.Util` and cross-module calls |
| [`samples/resolve/Lib.love`](../samples/resolve/Lib.love) | Exported `Sink` module for resolve (`Lib.love`) |
| [`samples/resolve/pkg/Util.love`](../samples/resolve/pkg/Util.love) | Mixed path for dotted module `pkg.Util` (`pkg/Util.love`) |
