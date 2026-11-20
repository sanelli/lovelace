# Augusta (standard library)

**Augusta** is Lovelace’s standard library (Ada Lovelace’s given name).

## Layout

| Path | Role |
| --- | --- |
| [`augusta/lovelace/`](../augusta/lovelace/) | Lovelace `.love` modules (in-tree `AUGUSTA_HOME` / `-I` root) |
| [`augusta/lovelace/augusta.std.io.love`](../augusta/lovelace/augusta.std.io.love) | Module `augusta.std.io` |
| [`augusta/libaugusta/`](../augusta/libaugusta/) | Freestanding Ada native library (future; `--flavor native`) |
| [`augusta/libaugusta-js/`](../augusta/libaugusta-js/) | JavaScript glue (future; `--flavor web`) |

Search roots treat the module name as a relative path under each root (mixed slash/dot forms). With `AUGUSTA_HOME` set to the in-tree [`augusta/lovelace/`](../augusta/lovelace/) directory, `import augusta.std.io;` resolves to `augusta.std.io.love` in that folder (the all-dot candidate). Nested `augusta/std/io.love` is the same module if present instead — exactly one existing form must match.

## Finding Augusta (`AUGUSTA_HOME`)

`lovelace build` appends exactly one Augusta slot after the root-file directory, cwd, and each `-I` path (see [cli.md](cli.md)):

1. `AUGUSTA_HOME` if set
2. else `LOVELACE_HOME/lib/augusta/<product-version>` if `LOVELACE_HOME` is set
3. else `~/.lovelace/lib/augusta/<product-version>`

`<product-version>` is the Lovelace product version **without** the git hash (e.g. `0.0.1-alpha.1` from `Lovelace.Common.Release.Version`).

For **in-tree** development and CI, set `AUGUSTA_HOME` to `{repo}/augusta/lovelace` (or pass `-I {repo}/augusta/lovelace`). Installed layout under the default slot:

```text
~/.lovelace/lib/augusta/0.0.1-alpha.1/augusta.std.io.love
```

## `augusta.std.io`

Public API (all flavors):

```love
export procedure print(value : integer);
```

| `--flavor` | Body |
| --- | --- |
| `wasi` (default) | `export @intrinsic procedure print(…);` — matched by signature `augusta.std.io.print(integer)→Unit`; backend synthesizes decimal ASCII + WASI 0.3 `write-via-stream` (no trailing newline). See [codegen.md](codegen.md). |
| `native` | Empty stub (compiles; does not print yet) |
| `web` | Empty stub (compiles; does not print yet) |

**TEMPORARY:** the wasi `print` is an `@intrinsic` so the backend can synthesize formatting and stdout writes. Once Lovelace has locals, assignment, loops, and integer arithmetic ([roadmap 1.002](roadmap/1.002-roadmap-replace-synthesized-print.md)), replace it with a normal Lovelace body — not an intrinsic — leaving only a narrow `PrintUTF8Character` synthesis until full WASI async is in-language. The same note lives as a `{ … }` comment above the wasi `print` declaration in [`augusta.std.io.love`](../augusta/lovelace/augusta.std.io.love).

Example:

```love
import augusta.std.io;
program HelloPrint;
begin
   augusta.std.io.print(42);
end.
```

Build with Augusta visible, then run:

```text
AUGUSTA_HOME=./augusta/lovelace lovelace build samples/io/HelloPrint.love --force
wasmtime run -Sp3 -W component-model-async=y .output/bin/HelloPrint.wasm
```
