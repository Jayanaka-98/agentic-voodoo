#!/usr/bin/env bash
# N runs each, both substrates, for pptx and algorithmic-art.
# Per-run CWD = outputs/<skill>/<substrate>/run-<i>/, so artifacts land there.
# Aggregate metrics under benchmarks/results/<batch>/.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BENCH_DIR="$REPO_ROOT/benchmarks"
SKILLS_ROOT="$REPO_ROOT/skills/anthropic/skills"
BATCH_ID="${BATCH_ID:-3way_$(date +%Y%m%d_%H%M%S)}"
RESULTS_DIR="$BENCH_DIR/results/$BATCH_ID"
OUTPUTS_ROOT="$REPO_ROOT/outputs"
mkdir -p "$RESULTS_DIR"

N=${1:-5}

run_one() {
    local label="$1" file="$2" skill_dir="$3" substrate="$4" run_id="$5"
    local workdir="$OUTPUTS_ROOT/$skill_dir/$substrate/run-$run_id"
    rm -rf "$workdir"
    mkdir -p "$workdir"
    echo "──── $label ────"
    (
        cd "$workdir"
        RUN_ID="$run_id" SKILLS_ROOT="$SKILLS_ROOT" RESULTS_DIR="$RESULTS_DIR" \
            jac run "$file" 2>&1 | tail -2
    )
}

# pptx
for i in $(seq 1 "$N"); do
    run_one "pptx Run $i/$N — BASELINE" "$BENCH_DIR/baseline/pptx_bench.jac" pptx baseline "$i"
    run_one "pptx Run $i/$N — OSP"      "$BENCH_DIR/osp/pptx_osp.jac"        pptx osp      "$i"
done

# algorithmic-art
for i in $(seq 1 "$N"); do
    run_one "art Run $i/$N — BASELINE" "$BENCH_DIR/baseline/algorithmic_art_bench.jac" algorithmic_art baseline "$i"
    run_one "art Run $i/$N — OSP"      "$BENCH_DIR/osp/algorithmic_art_osp.jac"        algorithmic_art osp      "$i"
done

echo ""
echo "──── DONE ────"
ls -la "$RESULTS_DIR"/pptx-*runs.jsonl "$RESULTS_DIR"/algorithmic-art-*runs.jsonl 2>/dev/null
echo ""
echo "Per-run artifacts: $OUTPUTS_ROOT/{pptx,algorithmic_art}/{baseline,osp}/run-N/"
echo "Metrics:           $RESULTS_DIR/"
