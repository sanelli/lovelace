# Host Ada API documentation (GNATdoc)

Host crates document Ada **specs** with [GNATdoc 4 annotations](https://docs.adacore.com/live/wave/gnatdoc4/html/gnatdoc-doc/annotations.html): leading comments, `@field` / `@disc` on records, `@enum` on enumeration literals, `@param` and `@return` on subprograms. Do not use inline comments for those.

This is the Ada toolchain API. Lovelace language docs stay with Alexandria (`lovelace doc`) and `docs/`.

## Generate HTML

1. Install **`gnatdoc`** and put `~/.alire/bin` on `PATH` (see README **Development tools**): `alr install gnatdoc`.
2. Build each crate once so Alire has written `config/` GPRs (`alr build` at the repo root, or `alr -C common build`, and so on).
3. From the repository root, run `pwsh scripts/gnatdoc.ps1`.

The script runs `alr exec -- gnatdoc --style=leading --backend html --output-dir docs/.code/<crate-folder> <crate>.gpr` for every host project listed in `$Projects` (excluding `lovelace_workspace`). HTML is written to `docs/.code/` (gitignored).

When you add a new host Alire crate, append its folder name and `.gpr` path to `$Projects` in `scripts/gnatdoc.ps1`.
