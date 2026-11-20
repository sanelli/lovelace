# Augusta (Lovelace sources)

`.love` modules for the **Augusta** standard library (named for Ada Lovelace’s given name). This folder is the in-tree `AUGUSTA_HOME` / `-I` root for Lovelace-authored Augusta packages.

Native Ada backing lives in [`../libaugusta/`](../libaugusta/); web JS glue in [`../libaugusta-js/`](../libaugusta-js/). Search-root rules and flavor behavior: [`docs/augusta.md`](../../docs/augusta.md).

## Modules

| File | Module | Role |
| --- | --- | --- |
| [`augusta.std.io.love`](augusta.std.io.love) | `augusta.std.io` | Console I/O. Exports `print(value : integer)`. Under `--flavor wasi` (default), `print` is a temporary `@intrinsic` synthesized by the backend. `--flavor native` and `--flavor web` provide empty stubs until those flavors are implemented. |

More Augusta packages will land here as the language and stdlib grow.
