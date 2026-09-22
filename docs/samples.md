# Samples

The [`samples/`](../samples/) tree holds small `.love` programs used to exercise features end-to-end (CLI builds, integration tests, and manual checks).

## Policy

For **every** new user-facing feature, add at least one `.love` file under `samples/` that exercises that feature.

- Prefer a focused program that demonstrates the feature with the smallest valid surface.
- Subfolders under `samples/` are allowed when grouping is needed (for example multi-file projects or solutions later).
- Keep sample `program` identifiers identical to the `.love` basename (excluding the extension).

## Current samples

| Path | Feature |
| --- | --- |
| [`samples/Hello.love`](../samples/Hello.love) | Minimal empty-body program for `lovelace build` and wasmtime integration |
