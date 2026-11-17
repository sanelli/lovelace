# Augusta

This directory is the **Augusta** standard library for Lovelace (named for Ada Lovelace’s given name). Sources here are `.love` modules only for now — no separate Alire crate and no native `libaugusta` yet.

Set `AUGUSTA_HOME` to this folder (or pass `-I` to it) so `lovelace build` can resolve imports. See [`docs/augusta.md`](../docs/augusta.md) for search-root rules and flavor behavior.

## Modules

| File | Module | Role |
| --- | --- | --- |
| [`augusta.std.io.love`](augusta.std.io.love) | `augusta.std.io` | Console I/O. Exports `print(value : integer)`. Under `--flavor wasi` (default), `print` is a temporary `native("wasi", "native-print-integer")` binding synthesized by the backend. `--flavor native` and `--flavor web` provide empty stubs until those flavors are implemented. |

More Augusta packages will land here as the language and stdlib grow.
