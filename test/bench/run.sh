#!/usr/bin/env bash

set -e

BIN=${1:?uso: test/bench/run.sh <binario> [entidades]}
N=${2:-10000}
FRAMES=${FRAMES:-600}
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$(mktemp)"

now() { perl -MTime::HiRes=time -e 'printf "%.3f", time'; }
to_seconds() { awk -F: '{ s = 0; for (i = 1; i <= NF; i++) s = s * 60 + $i; print s }'; }

START=$(now)
N=$N FRAMES=$FRAMES "$BIN" "$DIR" > "$OUT" 2>&1 &
PID=$!

PEAK=0
SUM=0
COUNT=0
CPU=0
while kill -0 "$PID" 2>/dev/null; do
  LINE=$(ps -o rss=,time= -p "$PID" 2>/dev/null || true)
  if [ -n "$LINE" ]; then
    RSS=$(echo "$LINE" | awk '{print $1}')
    CPU=$(echo "$LINE" | awk '{print $2}' | to_seconds)
    SUM=$((SUM + RSS))
    COUNT=$((COUNT + 1))
    [ "$RSS" -gt "$PEAK" ] && PEAK=$RSS
  fi
  sleep 0.2
done
END=$(now)

grep "RESULT\|ERROR\|^JIT" "$OUT" || { echo "sem RESULT, log em $OUT"; exit 1; }
awk -v peak="$PEAK" -v sum="$SUM" -v count="$COUNT" -v cpu="$CPU" -v start="$START" -v end="$END" 'BEGIN {
  wall = end - start
  printf "PROCESSO ram_pico_mb=%.1f ram_media_mb=%.1f cpu_s=%.2f tempo_s=%.2f cpu_medio=%.0f%%\n",
    peak / 1024, (count ? sum / count : 0) / 1024, cpu, wall, (wall > 0 ? cpu / wall * 100 : 0)
}'
rm -f "$OUT"
