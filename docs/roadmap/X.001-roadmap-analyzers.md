# Roadmap X.001: analyzers

**Objective:** Add compiler **analyzers** over LIR (and related IR) — **dataflow**, **liveness**, and similar analyses — as a foundation for diagnostics and for [X.002](X.002-roadmap-optimizers.md) optimizers.

Prerequisite: stable LIR / lowering from series 1–2 enough to analyze real programs.

## In scope

- Dataflow analysis framework (or equivalent reusable pass infrastructure)
- Liveness analysis
- Additional analyses as needed (reaching definitions, available expressions, etc. — TBC)
- Wire analyzers into the compiler pipeline; expose results to later passes and (where useful) diagnostics
- Tests on representative LIR snippets

## Out of scope

- Transforming / optimizing code → [X.002](X.002-roadmap-optimizers.md)
- User-defined source generators → [X.003](X.003-roadmap-source-generators.md)

## Status

Not started.
