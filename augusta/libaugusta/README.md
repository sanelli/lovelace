# libaugusta

Freestanding **Ada** implementation of Augusta for the **native** flavor (`--flavor native`).

This directory will hold the shared library sources and build that produce `libaugusta.so` / `libaugusta.dylib` / `libaugusta.dll` for Linux, macOS, and Windows. Lovelace-authored Augusta modules under [`../lovelace/`](../lovelace/) call into this native backing where the language cannot yet express host I/O directly.

See roadmap [1.004](../../docs/roadmap/1.004-roadmap-print-integer-native.md).
