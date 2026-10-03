# Samples

The [`samples/`](../samples/) tree holds small `.love` programs and modules used to exercise features end-to-end (CLI builds, integration tests, and manual checks). Build them with [`lovelace build`](cli.md).

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
