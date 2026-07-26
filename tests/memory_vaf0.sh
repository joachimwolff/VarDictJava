#!/bin/bash
# Demonstrate the VAF=0 (-f 0) memory inflation and how VarDict 1.8.4 (this fork) bounds it.
#
# At the default -f 0.01, VarDict only keeps positions with a variant allele fraction >= 1%. At -f 0
# it keeps EVERY covered base x allele, so the number of retained variant rows -- and the live object
# graph behind them (per-position VariationMaps) -- explodes. On a whole-chromosome -R interval that is
# what used to drive peak resident memory into tens/hundreds of GB.
#
# This script runs the same region at -f 0.01 and -f 0 and reports the row inflation and peak RSS, then
# (with the 1.8.4 build) at -f 0 --chunk to show the per-region live set being bounded.
#
# Reference result -- 1 Mb synthetic region, single thread, stock VarDictJava 1.8.3 vs this fork:
#   -f 0.01                              1904 rows    4.95 GB
#   -f 0    (inflated)                  23283 rows    6.47 GB   ~12x more rows, higher memory
#   -f 0    with 1.8.4 JVM defaults      23283 rows    3.55 GB   byte-identical output, ~1.8x less memory
#   -f 0    with --chunk 50000           (rows unchanged; peak RSS bounded regardless of region length)
#
# Usage: tests/memory_vaf0.sh <ref.fa> <in.bam> <chr:start-end>
#   Runs the installDist launcher build/install/VarDict/bin/VarDict by default (build it with
#   `./gradlew installDist`). To point at a raw jar instead, set:
#     VARDICT_JAR=/path/VarDict-1.8.4.jar  VARDICT_DEPS=commons-cli.jar:commons-math3.jar:htsjdk.jar:jregex.jar
set -u
REF=${1:?ref.fa}; BAM=${2:?in.bam}; RGN=${3:?chr:start-end}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$SCRIPT_DIR")"
if [ -n "${VARDICT_JAR:-}" ]; then
  RUN=(java -cp "$VARDICT_JAR:${VARDICT_DEPS:-}" com.astrazeneca.vardict.Main)
else
  RUN=("$ROOT/build/install/VarDict/bin/VarDict")
  [ -x "${RUN[0]}" ] || { echo "launcher not found: ${RUN[0]} -- run './gradlew installDist' or set VARDICT_JAR"; exit 1; }
fi
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
measure() {  # label, -f, extra... -> row of the table
  local label=$1 f=$2; shift 2
  if ! /usr/bin/time -v "${RUN[@]}" -G "$REF" -f "$f" -N s -b "$BAM" -R "$RGN" -th 1 "$@" >"$TMP/o" 2>"$TMP/t"; then
    printf "| %-26s | %8s | %10s |\n" "$label" "n/a" "n/a"; return; fi
  printf "| %-26s | %8s | %8s GB |\n" "$label" "$(grep -c . "$TMP/o")" \
    "$(awk '/Maximum resident/{printf "%.2f",$6/1048576}' "$TMP/t")"
}
echo "Region: $RGN   BAM: $(basename "$BAM")"
printf "| %-26s | %8s | %10s |\n" "setting" "rows" "peak RSS"
printf "|%s|%s|%s|\n" "----------------------------" "----------" "------------"
measure "-f 0.01 (default)" 0.01
measure "-f 0    (VAF=0, inflated)" 0
measure "-f 0    --chunk 50000" 0 --chunk 50000
echo
echo "Row count at -f 0 >> -f 0.01 is the inflation; --chunk bounds the per-region live set (memory)."
