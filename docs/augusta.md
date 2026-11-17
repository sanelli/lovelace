# Augusta (standard library)

**Augusta** is Lovelace’s standard library (Ada Lovelace’s given name). This tree is `.love` sources only for now — no separate Alire crate and no native `libaugusta` yet.

## Layout

| Path | Module |
| --- | --- |
| [`augusta/augusta.std.io.love`](../augusta/augusta.std.io.love) | `augusta.std.io` |

Search roots treat the module name as a relative path under each root (mixed slash/dot forms). With `AUGUSTA_HOME` set to the in-tree [`augusta/`](../augusta/) directory, `import augusta.std.io;` resolves to `augusta.std.io.love` in that folder (the all-dot candidate). Nested `augusta/std/io.love` is the same module if present instead — exactly one existing form must match.

## Finding Augusta (`AUGUSTA_HOME`)

`lovelace build` appends exactly one Augusta slot after the root-file directory, cwd, and each `-I` path (see [cli.md](cli.md)):

1. `AUGUSTA_HOME` if set
2. else `LOVELACE_HOME/lib/augusta` if `LOVELACE_HOME` is set
3. else `~/.lovelace/lib/augusta`

For **in-tree** development and CI, set `AUGUSTA_HOME` to `{repo}/augusta` (or pass `-I {repo}/augusta`). Installed layout under the default slot:

```text
~/.lovelace/lib/augusta/augusta.std.io.love
```

## `augusta.std.io`

Public API (all flavors):

```love
export procedure print(value : integer);
```

| `--flavor` | Body |
| --- | --- |
| `wasi` (default) | `native("wasi", "native-print-integer")` — backend synthesizes decimal ASCII + WASI 0.3 `write-via-stream` (no trailing newline). See [codegen.md](codegen.md). |
| `native` | Empty stub (compiles; does not print yet) |
| `web` | Empty stub (compiles; does not print yet) |

**TEMPORARY:** the wasi `print` is a `native(…)` binding so the backend can synthesize formatting and stdout writes. Once Lovelace has locals, assignment, loops, and integer arithmetic (roadmap step 10), replace it with a normal Lovelace body — not a native. (Source comments are not in the language yet; this note lives in docs.)

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
AUGUSTA_HOME=./augusta lovelace build samples/io/HelloPrint.love --force
wasmtime run -Sp3 -W component-model-async=y .output/bin/HelloPrint.wasm
```
