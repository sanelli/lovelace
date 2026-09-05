---
name: UTF-8 regex engine
overview: "Add host UTF-8/naming rules, then create the `lovelace_common` crate with a Thompson NFA regex engine (UTF-8/code-point aware, modeled on EML Regex_Automata) plus AUnit tests that prove each Lovelace token class can be matched — without implementing a lexer."
todos:
  - id: "1"
    content: 1. Create GitHub issue via gh issue create (reuse if one exists)
    status: completed
  - id: "2"
    content: 2. Create and check out feature/3-utf8-regex-engine
    status: completed
  - id: "3"
    content: 3. Save plan as .cursor/plans/3-utf8-regex-engine.plan.md
    status: completed
  - id: "4"
    content: "4. Update Cursor rules: UTF-8 strings/sources/4-byte chars; crate names lovelace_*; packages Lovelace.*"
    status: completed
  - id: "5"
    content: 5. Add -gnatW8 to shared/lovelace_host_switches.gpr
    status: completed
  - id: "6"
    content: "6. Create lovelace_common crate: Lovelace, Lovelace.Utf_8, Lovelace.Regex (Thompson NFA, UTF-8)"
    status: completed
  - id: "7"
    content: 7. Add common/tests (lovelace_common_tests, AUnit) for engine + each Lovelace token class
    status: completed
  - id: "8"
    content: 8. Document regex engine and UTF-8 conventions under docs/
    status: pending
  - id: "9"
    content: 9. Pin lovelace_common in lovelace_workspace (no CLI depends-on yet)
    status: pending
  - id: "10"
    content: 10. Run all tests that exist (workspace build + nested AUnit)
    status: pending
  - id: "11"
    content: 11. Push and open a PR with gh pr create
    status: pending
isProject: false
---

# UTF-8 common regex engine

#3 — [UTF-8 host strings and Thompson NFA regex engine in lovelace_common](https://github.com/sanelli/lovelace/issues/3)

Branch: `feature/3-utf8-regex-engine`

Do not implement a Lovelace lexer or `compiler/` tokenizer; only the host regex engine and tests that a pattern exists for each token class below.

```mermaid
flowchart LR
  pattern["UTF-8 pattern"]
  parse["Parse to AST"]
  nfa["Thompson NFA"]
  input["UTF-8 input"]
  decode["Decode code points"]
  match["Longest prefix"]
  pattern --> parse --> nfa
  input --> decode --> match
  nfa --> match
```

## 1. Create GitHub issue

Done: [#3](https://github.com/sanelli/lovelace/issues/3).

## 2. Create feature branch

Done: `feature/3-utf8-regex-engine` (based on `feature/1-host-alire-bootstrap`; includes unstaged workflow tweak commenting out `push` on `main` in [`.github/workflows/build.yml`](.github/workflows/build.yml)).

## 3. Save the plan

Done: [`.cursor/plans/3-utf8-regex-engine.plan.md`](.cursor/plans/3-utf8-regex-engine.plan.md).

## 4. Update Cursor rules first

Done: always-apply [`.cursor/rules/utf8-and-naming.mdc`](.cursor/rules/utf8-and-naming.mdc); crate names and UTF-8 on [`alire.mdc`](.cursor/rules/alire.mdc), [`lovelace-project.mdc`](.cursor/rules/lovelace-project.mdc), [`ada-standards.mdc`](.cursor/rules/ada-standards.mdc), and sibling rules.

## 5. Enable UTF-8 Ada sources in host switches

Done: `-gnatW8` in [`shared/lovelace_host_switches.gpr`](shared/lovelace_host_switches.gpr).

## 6. Create crate `lovelace_common` in `common/`

Done: crate `lovelace_common` with [`common/alire.toml`](common/alire.toml), [`common/lovelace_common.gpr`](common/lovelace_common.gpr) (`Library_Kind use "static"`), packages `Lovelace`, `Lovelace.Utf_8` (GNAT `-gnatyD` Mixed_Case; not `UTF_8`), and `Lovelace.Regex` (Thompson NFA, code-point classes, `Compile` / `Match_Prefix`). `alr -C common build` succeeds.

## 7. Nested AUnit crate `common/tests`

Done: crate `lovelace_common_tests` under [`common/tests/`](common/tests/) with AUnit, pin to `lovelace_common`, shared host switches. Fixtures cover engine mechanics (literal, concat, alt, quantifiers, classes, offsets, invalid patterns, UTF-8/`\u{…}`) and one pattern per token class (comments, strings, chars, ops, punct, keywords, parens, identifiers), including glued vs spaced inputs. `alr -C common/tests run` — 20/20 OK. Non-ASCII test data uses `Wide_Wide_String` + `Utf_8.Encode` (GNAT `-gnatW8` rejects emoji in `String` literals).

## 8. Document under `docs/`

Add a short host page (e.g. [`docs/regex-engine.md`](docs/regex-engine.md)): regex syntax, UTF-8 byte lengths, code-point classes, and that this is **not** the Lovelace lexer. Point the README at it in one line if the status/build section is touched. Public Ada APIs stay documented on the specs.

## 9. Wire the workspace

Root [`alire.toml`](alire.toml): `[[depends-on]]` + `[[pins]]` for `lovelace_common = { path = "common" }` in addition to `lovelace`. [`lovelace_workspace.gpr`](lovelace_workspace.gpr): add `common/lovelace_common.gpr` to `Project_Files`. Do **not** add `depends-on` from the `lovelace` executable to `lovelace_common` yet (avoids `procedure Lovelace` vs `package Lovelace`).

## 10. Run all tests

`alr build` at the repo root (workspace includes `lovelace_common`). Run the nested crate (`alr -C common/tests` build/test as Alire+AUnit require). Record results. If no other test crates exist, that is the full suite.

## 11. Push and open a PR

`git push` / `gh pr create` with proxy env vars cleared and `all` permissions (see agent-workflow). PR closes #3.
