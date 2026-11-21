# Samples

The [`samples/`](../samples/) tree holds small `.love` programs and modules used to exercise features end-to-end (CLI builds, integration tests, and manual checks). Build them with [`lovelace build`](cli.md).

Integration tests (`lovelace/lovelace/integration_tests`) require `wasm-tools` and `wasmtime` on `PATH`, build these samples (suppressing `[info]` stdout), validate every `.wasm`/`.wat`, and **run** only program/entrypoint artifacts. See the integration-tests Cursor rule.

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
| [`samples/using/UsingDecl.love`](../samples/using/UsingDecl.love) | File-leading `using UsingLib;` before an empty-body program (resolves same-folder module) |
| [`samples/using/UsingLib.love`](../samples/using/UsingLib.love) | Empty module dependency for `UsingDecl` |
| [`samples/nested-using/NestedUsing.love`](../samples/nested-using/NestedUsing.love) | Block-scoped `using` + declare + assign + print (needs Augusta) |
| [`samples/assignment/Assignment.love`](../samples/assignment/Assignment.love) | Declare, `:=`, read, print via Augusta |
| [`samples/module/Empty.love`](../samples/module/Empty.love) | Minimal empty module (`module Empty; end.`) |
| [`samples/module/Foo.Bar.love`](../samples/module/Foo.Bar.love) | Dotted module name (`module Foo.Bar; end.`) |
| [`samples/module/Procedures.love`](../samples/module/Procedures.love) | Module procedures with Ada-style typed parameters |
| [`samples/module/ExportProcedures.love`](../samples/module/ExportProcedures.love) | `export procedure` (Lovelace visibility) plus a non-exported helper |
| [`samples/io/HelloPrint.love`](../samples/io/HelloPrint.love) | `using augusta.std.io;` then `augusta.std.io.print(42);` (needs `AUGUSTA_HOME=augusta/lovelace` or `-I augusta/lovelace`; wasi `print` is `@intrinsic`) |
| [`samples/comments/Comments.love`](../samples/comments/Comments.love) | `{ … }` block comments (non-nesting; ignored like whitespace) |
| [`samples/literals/Literals.love`](../samples/literals/Literals.love) | Integer literals with `0x` / `0b` / `0o` prefixes in call args |
| [`samples/boolean/Boolean.love`](../samples/boolean/Boolean.love) | `boolean` params and `true`/`false` call args |
| [`samples/variables/Variables.love`](../samples/variables/Variables.love) | Nested `declare` / block statements (outer locals + nested + bare nested `begin`…`end;`; unused locals may warn) |
| [`samples/emoji/🚀.love`](../samples/emoji/🚀.love) | Emoji program name + emoji local (`declare`) |
| [`samples/emoji-module/🛸.love`](../samples/emoji-module/🛸.love) | Emoji module name, emoji procedure, emoji local (🛸 so output basename differs from program 🚀) |
| [`samples/directives/FlavorSelect.love`](../samples/directives/FlavorSelect.love) | Flavor `#if` / `#elsif` / `#else` / `#end` (default `--flavor wasi` keeps `WasiOnly`) |
| [`samples/calls/SameModuleCall.love`](../samples/calls/SameModuleCall.love) | Same-unit qualified call with integer literal (`SameModuleCall.Sink(42)`) |
| [`samples/overload/Overload.love`](../samples/overload/Overload.love) | Same-module overload: `Sink(integer)` / `Sink(boolean)` / `Sink(integer<8>)`; `42s32` / `true` / `1s8` (bare `42` would be ambiguous) |
| [`samples/overload/OverloadLib.love`](../samples/overload/OverloadLib.love) | Exported `Sink` overloads for cross-module callers |
| [`samples/overload/OverloadCaller.love`](../samples/overload/OverloadCaller.love) | `using OverloadLib;` then `Sink(7)` / `Sink(false)` (resolve by actual types) |
| [`samples/resolve/Caller.love`](../samples/resolve/Caller.love) | Multi-unit program: `using Lib` / `using pkg.Util` and cross-module calls |
| [`samples/resolve/Lib.love`](../samples/resolve/Lib.love) | Exported `Sink` module for resolve (`Lib.love`) |
| [`samples/resolve/pkg/Util.love`](../samples/resolve/pkg/Util.love) | Mixed path for dotted module `pkg.Util` (`pkg/Util.love`) |
