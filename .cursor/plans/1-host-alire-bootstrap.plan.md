---
name: Host Alire bootstrap
overview: "Bootstrap the first host Alire layout (do-nothing `lovelace` executable, shared host GPR, root `lovelace_workspace`), using the mandatory plan envelope: GitHub issue, feature branch, plan file under `.cursor/plans`, then implement, then tests, then PR."
todos:
  - id: "1"
    content: 1. Create GitHub issue via gh issue create (reuse if one exists)
    status: completed
  - id: "2"
    content: 2. Create and check out feature/1-host-alire-bootstrap
    status: completed
  - id: "3"
    content: 3. Save plan as .cursor/plans/1-host-alire-bootstrap.plan.md
    status: completed
  - id: "4"
    content: 4. Add abstract shared/lovelace_host_switches.gpr (Ada 2022, -gnatwae, full -gnaty, -gnatyM79, -gnato, -fstack-check)
    status: completed
  - id: "5"
    content: 5. Add lovelace/ alire.toml + lovelace.gpr + src/lovelace.adb (null main); with shared switches; auto-gpr-with = false
    status: completed
  - id: "6"
    content: 6. Add root lovelace_workspace alire.toml (depends-on + pin) and aggregate lovelace_workspace.gpr
    status: completed
  - id: "7"
    content: 7. Ignore Alire/GNAT build trees; optional README build lines
    status: completed
  - id: "8"
    content: 8. Verify alr build at root and in lovelace/
    status: completed
  - id: "9"
    content: 9. Run all tests (none expected; record and continue)
    status: completed
  - id: "10"
    content: 10. Push and open a PR with gh pr create
    status: completed
isProject: false
---

# Host Alire bootstrap

#1 — [Bootstrap lovelace CLI crate, shared host GPR, and workspace aggregate](https://github.com/sanelli/lovelace/issues/1)

Branch: `feature/1-host-alire-bootstrap`

Do not scaffold `compiler/`, `common/`, other host crates, nested tests, or CLI behavior.

```mermaid
flowchart TD
  root["lovelace_workspace (root, no Ada)"]
  cli["lovelace (executable)"]
  sw["shared/lovelace_host_switches.gpr"]
  root -->|"depends-on + pin"| cli
  root -->|"aggregate Project_Files"| cli
  cli -->|"with + concatenate switches"| sw
```

The repo has rules and a README, but no `alire.toml`, `.gpr`, or Ada sources yet.

## 1. Create GitHub issue

Done: [#1](https://github.com/sanelli/lovelace/issues/1).

## 2. Create feature branch

Done: `feature/1-host-alire-bootstrap`.

## 3. Save the plan

Done: [`.cursor/plans/1-host-alire-bootstrap.plan.md`](.cursor/plans/1-host-alire-bootstrap.plan.md).

## 4. Shared host switches (not a crate)

Create [`shared/lovelace_host_switches.gpr`](shared/lovelace_host_switches.gpr) as an abstract project with no sources. Export `Ada_Compiler_Switches` so host crates concatenate it and do not copy the list.

- `-gnat2022`, `-gnatwae`, `-gnato`, `-fstack-check`
- `-gnatyy` plus extras `-gnatyABDdIoOSuxz` and `-gnatyM79`
- Omit `-gnatyg`, `-gnatyN`, `-gnatyC`

Crate `alire.toml` files: `"*".style_checks = "No"` so Alire cannot weaken the shared GPR. Keep Alire profiles for `-g` / `-O*` / contracts only.

## 5. `lovelace` executable crate

Hand-write (no extra `alr init` skeleton):

- [`lovelace/alire.toml`](lovelace/alire.toml) — name `lovelace`, MIT, author Stefano Anelli, `executables = ["lovelace"]`, no sibling `depends-on`, `auto-gpr-with = false`
- [`lovelace/lovelace.gpr`](lovelace/lovelace.gpr) — application project; `with` `config/lovelace_config.gpr` and `../shared/lovelace_host_switches.gpr`; concatenate `Lovelace_Config.Ada_Compiler_Switches & Lovelace_Host_Switches.Ada_Compiler_Switches`; `Main` `lovelace.adb`
- [`lovelace/src/lovelace.adb`](lovelace/src/lovelace.adb) — `procedure Lovelace is begin null; end Lovelace;`

No nested `lovelace/tests`. No CLI docs.

## 6. Root thin aggregate `lovelace_workspace`

- Root [`alire.toml`](alire.toml) — crate `lovelace_workspace`; `[[depends-on]] lovelace = "*"` and `[[pins]] lovelace = { path = "lovelace" }` only. No `project-files` array of component GPRs.
- [`lovelace_workspace.gpr`](lovelace_workspace.gpr) — `aggregate project` with `Project_Files` `("lovelace/lovelace.gpr")`. If Alire config `with`s cannot sit on an aggregate, use the minimal GPR gprbuild accepts (still one file, still the pin graph).

## 7. Ignore build trees

Extend [`.gitignore`](.gitignore) for `**/alire/`, `**/obj/`, `**/bin/`, `**/config/`. Optionally two README lines: `alr build` at root, or `alr -C lovelace run`.

## 8. Verify the build

Done. With `LIBRARY_PATH` including the macOS SDK `usr/lib` (needed for linking with the Alire GNAT toolchain on this host), `alr build` at the repo root and `alr -C lovelace build` both succeed; `lovelace/bin/lovelace` runs and exits 0. Compile line includes `-gnat2022`, `-gnatwae`, `-gnato`, `-fstack-check`, `-gnatyy`, `-gnatyABDdIoOSuxz`, `-gnatyM79`.

## 9. Run all tests

Done. No nested AUnit test crates exist in the repository; nothing to run.

## 10. Push and open a PR

Done. Branch pushed; PR [#2](https://github.com/sanelli/lovelace/pull/2) opened (closes #1).
