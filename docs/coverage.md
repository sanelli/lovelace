# Host Ada coverage, complexity, and CRAP

Roadmap [1.002](roadmap/1.002-roadmap-replace-synthesized-print.md) macro step 7 / [#47](https://github.com/sanelli/lovelace/issues/47).

Host library and CLI Ada are measured with **gnatcov** (coverage) and **gnatmetric** (complexity). Scripts under `scripts/` gate thresholds locally and on pull requests. Integration tests and Lovelace `.love` sources are out of scope for these gates.

## Install tools

**Local** (see README **Development tools**); ensure `~/.alire/bin` is on `PATH`:

```bash
alr install gnatcov
alr install libadalang_tools   # gnatmetric (+ gnatformat)
```

**CI** (`quality` job): installs `gnatcov` via Alire and **`gnatmetric` via** [`sanelli/libadalang_tools-dist`](https://github.com/sanelli/libadalang_tools-dist) (prebuilt zip for `ubuntu-26.04` / crate `26.0.0`). Scripts stay the same — they only require `gnatmetric` on `PATH`.

`gnatcov` and `gnatmetric` are **host tools** (not crate `depends-on`). The first coverage run may execute `gnatcov setup` into `~/.alire` if the coverage runtime is missing (`scripts/coverage.ps1` does this idempotently).

## Local commands

From the repository root (PowerShell):

```powershell
pwsh scripts/coverage.ps1          # instrument unit tests → .coverage/
pwsh scripts/metrics.ps1           # gnatmetric XML → .metrics/
pwsh scripts/crap.ps1              # join CC + stmt cov → CRAP (needs both above)
pwsh scripts/quality-report.ps1    # Markdown table → .coverage/quality-report.md
```

Order: **coverage** and **metrics** before **crap**; all three summaries before **quality-report**.

Optional `-SkipGates` on coverage/metrics/crap prints numbers without failing (local exploration only — **CI must not use it**).

Output dirs (gitignored): `.coverage/`, `.metrics/`, `*.srctrace`, instrumented `gnatcov-instr` trees.

## What is measured

| Tool | Scope |
| --- | --- |
| **gnatcov** | Host projects `lovelace_common`, `lovelace_lir`, `lovelace_compiler`, `lovelace` |
| **Drivers** | Unit-test crates only (`common/tests`, `lir/tests`, `compiler/tests`, `lovelace/tests`) |
| **gnatmetric** | Same four library/CLI projects (bodies; tests excluded) |

Coverage level: **`stmt+decision+fun_call`**. Call-site half of `fun_call` is **report-only** (not a gate).

## Gates

Thresholds live in the scripts and must match this table:

| Metric | Gate |
| --- | --- |
| Statement coverage | ≥ **95%** |
| Decision coverage | ≥ **93%** |
| Subprogram / fun_call (combined Function+call fully covered) | ≥ **95%** |
| Cyclomatic complexity (per unit) | ≤ **10** |
| Essential complexity (per unit) | ≤ **10** |
| Max loop nesting (per unit) | ≤ **4** |
| CRAP (per joined unit) | ≤ **30** |

Coupling, extra exits, average CRAP, and call-site coverage are **info only**.

Exit codes for gate scripts: **0** pass, **1** gate failure, **2** tool/parse failure (fail-closed).

## CRAP

Per subprogram:

```text
CRAP(m) = CC(m)^2 * (1 - cov(m)/100)^3 + CC(m)
```

- `CC(m)` — gnatmetric cyclomatic complexity (`.metrics/units.json`)
- `cov(m)` — gnatcov statement fully-covered % for that scope (`.coverage/xml/`)

**Join key** (see `scripts/crap.ps1`): `lowercase(basename)|unit_name|line`. Units with no matching coverage scope get **cov = 0** (fail-closed).

## Sticky PR comment

`scripts/quality-report.ps1` writes Markdown with marker `<!-- lovelace-quality-metrics -->`.

On pull requests, CI posts or updates one sticky comment from that Markdown (✅ / ⛔️ per gated row). Local runs only write `.coverage/quality-report.md` unless you pass `-PostPullRequestComment` with `gh` authenticated.

## CI

The **`quality`** job in [`.github/workflows/build.yml`](../.github/workflows/build.yml) runs **only on `pull_request`** (not on `push` to `main`): encoding check → Alire/`gnatcov` → **`sanelli/libadalang_tools-dist` (`gnatmetric`)** → coverage → metrics → crap → quality report + sticky comment. Any gate failure fails the check; the sticky comment is still updated when summaries exist.

The ordinary **`build`** job (build + unit + integration) keeps running on both PR and `main` push.

## Troubleshooting

| Symptom | What to try |
| --- | --- |
| `gnatcov` / `gnatcov_rts` not found | `alr install gnatcov`; put `~/.alire/bin` on `PATH`; let `coverage.ps1` run `gnatcov setup` |
| `gnatmetric` not found | Local: `alr install libadalang_tools`. CI: ensure `sanelli/libadalang_tools-dist` release has a zip for this runner image + crate version |
| Stale instrumented sources | Delete `**/gnatcov-instr/` and `.coverage/`, re-run `coverage.ps1` |
| macOS link / SDK errors | Set `LIBRARY_PATH` and `MACOSX_DEPLOYMENT_TARGET` (README **macOS setup**); coverage.ps1 also tunes SDK paths |
| CRAP spikes after a refactor | Re-run metrics then coverage then crap; unmatched units count as 0% cov |
| Decision % stuck | Cover **both** sides of boolean decisions; prefer in-process AUnit over spawning an uninstrumented CLI |
| `quality-report.ps1` missing JSON | Run coverage, metrics, and crap first (in that dependency order for crap) |
