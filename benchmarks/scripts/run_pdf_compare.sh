#!/usr/bin/env bash
# Head-to-head: pdf_bench (baseline) vs pdf_osp at N runs each.
# Per-run artifacts isolated under outputs/pdf/<substrate>/run-<i>/ (also their CWD).
# Aggregate metrics under benchmarks/results/<batch>/.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BENCH_DIR="$REPO_ROOT/benchmarks"
SKILLS_ROOT="$REPO_ROOT/skills/anthropic/skills"
BATCH_ID="${BATCH_ID:-pdf_$(date +%Y%m%d_%H%M%S)}"
RESULTS_DIR="$BENCH_DIR/results/$BATCH_ID"
OUTPUTS_ROOT="$REPO_ROOT/outputs/pdf"
mkdir -p "$RESULTS_DIR"

N=${1:-5}

run_one() {
    local label="$1" file="$2" substrate="$3" run_id="$4"
    local workdir="$OUTPUTS_ROOT/$substrate/run-$run_id"
    rm -rf "$workdir"
    mkdir -p "$workdir"
    echo "──── $label ────"
    (
        cd "$workdir"
        RUN_ID="$run_id" SKILLS_ROOT="$SKILLS_ROOT" RESULTS_DIR="$RESULTS_DIR" \
            jac run "$file" 2>&1 | tail -3
    )
}

for i in $(seq 1 "$N"); do
    run_one "Run $i/$N — BASELINE" "$BENCH_DIR/baseline/pdf_bench.jac" baseline "$i"
    run_one "Run $i/$N — OSP"      "$BENCH_DIR/osp/pdf_osp.jac"        osp      "$i"
done

echo ""
echo "──── DONE ────"
ls -la "$RESULTS_DIR"/pdf-*runs.jsonl 2>/dev/null
echo ""
echo "Per-run artifacts: $OUTPUTS_ROOT/{baseline,osp}/run-N/"
echo "Metrics:           $RESULTS_DIR/"
