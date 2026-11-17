# Roadmap Z.001: invoke native code from Lovelace

**Objective:** Give developers the ability to **invoke native code** — e.g. a **Rust**, **Ada**, or **C** library package — from Lovelace programs (FFI / binding mechanism TBC).

Prerequisite: native host path from [1.004](1.004-roadmap-print-integer-native.md); package story may interact with [X.001](X.001-roadmap-package-manager.md).

## In scope

- Binding / import mechanism for external native libraries
- ABI and safety rules for v1 (what is allowed across the boundary)
- Packaging conventions for shipping a native artifact with a Lovelace package
- Samples calling a small C/Rust/Ada library
- Docs for binding authors

## Out of scope

- First-party native UI toolkit → [Z.002](Z.002-roadmap-native-ui.md)
- Replacing Augusta’s own freestanding syscall layer

## Status

Not started.
