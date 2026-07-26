# VarDictJava 1.8.4 — maintained fork

This is a community-maintained fork of [AstraZeneca-NGS/VarDictJava](https://github.com/AstraZeneca-NGS/VarDictJava),
which upstream marks as the **final version and no longer maintains**. This release continues from 1.8.3
and fixes VarDict's **memory footprint**, while keeping variant output **byte-identical** to 1.8.3.

## What's new
- **Lower memory footprint** (footprint only — output unchanged): `VariationMap` initial capacity 16 → 4,
  and `-XX:+UseG1GC -XX:+UseStringDeduplication` as JVM defaults so peak RSS tracks the live set instead
  of `-Xmx`.
- **New opt-in `--chunk INT`**: splits long `-R` regions to bound the per-region live set, so
  whole-chromosome or high-sensitivity (`-f 0`) runs no longer scale memory into the tens/hundreds of GB.
  Off by default (byte-identical); when enabled, only the `Seg` column reflects the sub-regions.
- **GitHub Actions CI**: runs the full TestNG suite (all 92 integration cases + unit tests) on JDK 8.
- **`tests/memory_vaf0.sh`**: reproducible demonstration of the VAF=0 memory inflation and the fix.

## Correctness
Byte-identical to VarDict 1.8.3 on **all 92 integration test cases** (verified in CI).

## Memory — VAF=0 (`-f 0`) case, 1 Mb region, single thread
| run | variant rows | peak RSS |
|---|---|---|
| `-f 0.01` (default) | 1,904 | 4.95 GB |
| `-f 0` — stock 1.8.3 | 23,283 (~12× more) | 6.47 GB |
| `-f 0` — 1.8.4 defaults | 23,283 (identical output) | 3.55 GB (~1.8× less) |

The advantage grows with region size; use `--chunk` to keep memory bounded on very large single regions.
