# Roadmap: integer print, WASI-first Augusta, unit imports

Macro implementation steps for the first end-to-end I/O milestone:

- Single Augusta module source with `#if` flavor arms (no partial modules, no flavor-file merge)
- Print of **signed integer** (not strings yet)
- **WASI** flavor first (stock `wasmtime run`; no `lovelace_jit` / `love:` / `libaugusta` yet)
- Unit-level `import IDENTIFIER(.IDENTIFIER)*;` with calls only as `MODULE.SUBROUTINE`
- Imports allowed in `module` and `program` units only (not inside subroutines)
- Later: build all three flavors into separate output folders when those bodies exist

Related project rules: Augusta flavors (`native` / `wasi` / `web`), component codegen (`wasi:cli/run`), directives as real language syntax (not a separate preprocessor).

## Locked decisions

1. **Linking model (v1):** multi-unit compile → **one** component (program + Augusta sources). Defer true component-to-component linking. LIR `Dependencies` may record module names; the emitted artifact is still one WASM/WAT/WIT set.
2. **Import visibility vs WIT export:** Lovelace `import` is compile/link-time visibility of exported Lovelace symbols. A WIT/component export of `print` is separate and not required for the first console demo if everything lands in one component.
3. **WASI binding (v1):** sync Augusta wrapper around the smallest stdout write path (e.g. blocking write/flush). Do not require Lovelace `async` / `future` / `stream` in the language yet.
4. **Integer formatting (v1 fork):** prefer **A** then migrate to **B**:
   - **A.** Host/WASI helper takes `s32` and formats (fastest path).
   - **B.** Augusta formats to bytes and calls a `list<u8>` write (needs memory / Canonical ABI).
5. **`#if` grammar (v1):** only flavor selection — `#if flavor = "wasi" | "native" | "web"` with `#elsif` / `#else` / `#end` (exact end-token TBD). No general macro language.
6. **CLI:** `--flavor wasi` (default `wasi` for now). Triple output folders are a later step.
7. **Future (reserved, not in this milestone):** `import … as …`; partial modules; native JIT + `libaugusta`; web/JS glue; user-facing `string` / arrays / records; full WASI async in the language.

### Import grammar (this milestone)

```ebnf
import_declaration = "import" , identifier , { "." , identifier } , ";" ;
```

Example:

```love
program Hello;
import augusta.std.io;
begin
   augusta.std.io.print(42);
end.
```

Resolution rule (recommended): exact module import required — `import augusta.std.io;` is required to call `augusta.std.io.print`.

Reserved for later:

```love
import augusta.std.io as stdio;
(* stdio.print(42); *)
```

### Augusta shape (single file, `#if`)

Logical module `augusta.std.io` in one `.love` file:

- Shared exports / signatures (and any truly common code)
- `#if flavor = "wasi"` — real WASI implementation
- `#elsif flavor = "native"` / `#elsif flavor = "web"` — stubs until those flavors are implemented

### Flavor artifact layout (eventually)

When native/web bodies exist, build may emit under separate folders, e.g. `bin/wasi/`, `bin/native/`, `bin/web/` (and matching `.lir`). Still one module source tree with `#if`.

## Dependency graph

```text
1 #if flavor
    ↓
2 export (visibility) ──→ 3 import syntax
    ↓                        ↓
4 calls + literals ←────── 5 multi-unit resolve
    ↓
6 external/WASI decls → 7 backend imports → 8 Augusta.io → 9 sample/E2E
    ↓
10 locals/exprs/casts     11 flavor output dirs
```

Steps 1–3 are mostly frontend. Steps 4–5 make the language callable across modules. Steps 6–9 are the I/O cut. Steps 10–11 are follow-ons.

## Macro steps

### 1. Directives: flavor `#if` (parse + select)

**Goal:** Compile-time flavor selection in source.

- Tokenizer: `#if`, `#elsif`, `#else`, `#end` (or chosen end form), `flavor`, string compares as needed.
- Parser: directives are real syntax (see language rules). Inactive arms are not present in the AST used for lowering.
- Compiler option / project default: `flavor = wasi`.
- Tests: same file, different flavors → different surviving declarations.
- No Augusta required; a dummy module with `#if` is enough.

**Out of scope:** general expressions in `#if`, `#pragma` warning control, platform OS splits inside native (that stays in Ada native backing later).

### 2. `export` on module procedures

**Goal:** Stdlib symbols can be visible to importers.

- Grammar + AST/LIR export flags for module procedures (programs already use export/entrypoint bits).
- `export procedure print(value : integer);` (doc-comment when that feature exists).
- Clarify policy: Lovelace export-for-import vs WIT kebab export. For v1 one-component builds, prefer **Lovelace visibility** without forcing Canonical ABI export of `print` on day one.
- Today’s backend rejects export/entrypoint **with parameters** for WIT — do not conflate that limitation with intra-component calls to Augusta.

### 3. Unit-level `import` (syntax + AST only)

**Goal:** Parse and persist imports; no resolution yet.

- Grammar as above; only in `program` and `module` unit headers (before procedures / before `begin`).
- AST: list of imported module names (keep shape open for a future optional `as` alias).
- Lower to LIR `Dependencies` (module names only).
- Docs: reserve `import … as …` without implementing it.
- Tests: parse success/failure; imports rejected inside subroutine bodies.

### 4. Statements: qualified calls + integer literal arguments

**Goal:** Minimal executable bodies.

- Allow `augusta.std.io.print(42);` in `program` `begin`…`end` and in module procedure bodies.
- No locals/assignment required if literal arguments suffice for the demo.
- IR: call (+ const / literal operand).
- Avoid inventing a second call syntax; unqualified same-module calls can wait or land in the same slice if cheap.
- Backend: lower calls between functions in the same core module (still no WASI imports).

### 5. Multi-unit build + import resolution

**Goal:** `import` actually finds Augusta (or other) modules.

- `lovelace build` loads the root program/module plus imports via a search path / implicit `augusta/` root.
- Map dotted module name → file (`augusta.std.io` ↔ `augusta/std/io.love` or the path convention locked in this step).
- Resolve `MODULE.SUBROUTINE` only when `import MODULE;` is present.
- Merge/lower into one LIR module **or** keep multiple LIR modules and a link step that still emits **one** WASM component for v1.
- Diagnostics: unknown module, unknown subroutine, call without import (unused-import warning optional later).
- Apply flavor `#if` when loading each unit.

### 6. External / WASI import declarations (language + LIR)

**Goal:** Augusta can declare procedures satisfied by WASI component imports.

- Syntax for external imports (e.g. `native("wasi", …)` or a dedicated WASI import form — pick one and document it).
- Only meaningful inside `#if flavor = "wasi"` for this milestone.
- LIR: represent component/external imports (distinct from Lovelace module dependencies).
- No `love:` namespace, no dynamic library loading.

### 7. Backend: emit WASI imports + lower calls to them

**Goal:** Generated components import stdout/write and call them.

- Extend emission beyond export-only `wasi:cli/run@0.3.0`: add the WASI imports Augusta needs.
- Canon lower + core `call` to imports.
- If path **A** (typed `s32` print helper): may avoid guest linear memory initially.
- If path **B** (`list<u8>`): add minimal memory + `cabi_realloc` as required by Canonical ABI.
- Validate with `wasm-tools` and `wasmtime run -Sp3` (async flags as required by the WASI preview in use).

### 8. Augusta `augusta.std.io` (WASI body live; others stubbed)

**Goal:** First stdlib module in-tree.

- Add `augusta/` sources (`.love` only; no `lovelace_augusta` crate yet).
- Single file with `#if` arms:
  - **wasi:** real `print(integer)` implementation
  - **native** / **web:** stub or clear “unimplemented for this flavor” failure until those milestones
- Public API: `export procedure print(value : integer);`
- Document module path and flavor behavior under `docs/`.

### 9. End-to-end sample + tests

**Goal:** Prove console output.

- Sample under `samples/` feature folder (e.g. `samples/io/HelloPrint.love` or similar — follow samples layout rules).
- Program imports `augusta.std.io` and prints a literal integer (e.g. `42`).
- AUnit: parse, resolve, lowering, backend fragments as appropriate.
- Integration: build + `wasmtime` run shows the decimal output (define newline policy).
- Update `docs/samples.md`, CLI/grammar/codegen docs as needed.

### 10. Integer language path (after first green print)

**Goal:** Grow the language on a working I/O spine.

Order after step 9:

1. Locals + assignment
2. Integer expressions + explicit casts
3. Later (separate milestone): program parameters / CLI argv (likely strings — do not couple to step 9)

### 11. Flavor artifact layout

**Goal:** Separate build outputs per flavor when useful.

- `--flavor wasi|native|web`
- Emit under per-flavor directories (e.g. `bin/wasi/`, `bin/native/`, `bin/web/` and matching `.lir`)
- CI: wasi always; native/web when those arms are real
- Source remains one `#if`-based tree

### 12. Explicitly deferred

Do **not** pull these into steps 1–9:

- `import … as …` (and generic module aliases)
- Partial modules / narrow merge of `io.wasi.love`-style files
- `lovelace_jit`, `love:` imports, freestanding `libaugusta`
- Web flavor JS glue / core-module-only browser path
- User-facing `string` (record + array + length), arrays, records as general features
- Full WASI async streams/futures in Lovelace syntax
- True multi-component linking of separate Augusta and program artifacts

## Smallest vertical slice

Ship steps **1 (minimal) + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9** with:

- only the wasi `#if` arm functional
- native/web arms stubbed
- formatting path **A** unless memory ABI is already required

Then do **10**, then native/web + **11** as separate milestones.

## Open choices to lock in the first implementation issue

| Topic | Options | Recommendation |
|---|---|---|
| Formatting | A: host/`s32` · B: bytes in Augusta | A, then B |
| External decl syntax | `native("wasi", …)` vs dedicated WASI import form | Pick one in issue #1 of this work |
| `#end` token | `#end` / `#endif` / … | Match other directives style when introduced |
| Augusta path | `augusta/std/io.love` vs `augusta.std.io.love` | Match dotted module ↔ path rule from step 5 |
| One LIR vs many before emit | Merge early vs link LIR then emit | Either fine if one component results |
