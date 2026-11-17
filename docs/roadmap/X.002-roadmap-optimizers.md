# Roadmap X.002: optimizers

**Objective:** Add compiler **optimizers** driven by [X.001](X.001-roadmap-analyzers.md) analyses, including at least:

- Constant propagation
- Copy propagation
- Common subexpression elimination (CSE)
- Dead code elimination (DCE)
- Loop optimizations
- SSA (form and/or transforms — TBC)
- Tail recursion optimization

Prerequisite: [X.001](X.001-roadmap-analyzers.md).

## In scope

- Optimizer pass pipeline over LIR (or agreed IR stage)
- Correctness tests (semantic equivalence) and selected performance/smoke checks
- Clear interaction with debug info / source maps where applicable

## Out of scope

- User-authored codegen plugins → [X.003](X.003-roadmap-source-generators.md)
- Language feature work → series 2

## Status

Not started.
