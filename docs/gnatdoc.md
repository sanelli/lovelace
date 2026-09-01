# Host Ada API documentation (GNATdoc)

Host crates document Ada **specs** with [GNATdoc 4 annotations](https://docs.adacore.com/live/wave/gnatdoc4/html/gnatdoc-doc/annotations.html): leading comments, `@field` / `@disc` on records, `@enum` on enumeration literals, `@param` and `@return` on subprograms. Do not use inline comments for those.

This is the Ada toolchain API. Lovelace language docs stay with Alexandria (`lovelace doc`) and `docs/`.

## Generate HTML

1. Put the **GNATdoc 4** `gnatdoc` binary on `PATH` ([Alire crate `gnatdoc`](https://alire.ada.dev/crates/gnatdoc)), for example `alr install --prefix $HOME/.local gnatdoc`.
2. Build each crate once so Alire has written `config/` GPRs (`alr -C common build`, `alr -C lovelace build`).
3. From the repository root, run `pwsh scripts/gnatdoc.ps1`.

The script calls `alr exec -- gnatdoc --style=leading --warnings -O gnatdoc -P <crate.gpr>` in each existing host crate. HTML is written to `<crate>/gnatdoc/` (gitignored).
