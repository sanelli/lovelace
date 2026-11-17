# Roadmap X.003: user-defined source generators

**Objective:** Allow **Lovelace user-defined source generators** — plugins / extensions that generate or rewrite Lovelace (or adjacent) sources as part of the build, under a documented API and trust model.

Prerequisite: stable build/CLI story; package distribution may interact with [Y.001](Y.001-roadmap-package-manager.md).

## In scope

- Extension point for user source generators (invocation, inputs/outputs, diagnostics — TBC)
- Sandboxing / trust / versioning policy for generators (TBC)
- Samples of a minimal generator and docs for authors
- Integration with `lovelace build` (and later the package manager)

## Out of scope

- Built-in analyzer/optimizer passes → [X.001](X.001-roadmap-analyzers.md) / [X.002](X.002-roadmap-optimizers.md)
- Arbitrary native FFI → [Z.001](Z.001-roadmap-invoke-native-code.md)

## Status

Not started.
