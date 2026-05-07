#!/usr/bin/env bash
# Run all baseline skill benchmarks.
# Usage:
#   ./benchmarks/scripts/run_all.sh                 # all skills
#   ./benchmarks/scripts/run_all.sh pdf pptx        # specific skills
#
# Layout (per run):
#   outputs/<skill>/baseline/run-1/   ← CWD while bench runs (artifacts land here)
#   benchmarks/results/<batch>/       ← *_runs.jsonl, *_results.json, context_breakdown.json
#
# Requires: OPENAI_API_KEY (or whichever provider jac.toml selects).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BENCH_DIR="$REPO_ROOT/benchmarks"
SKILLS_ROOT="$REPO_ROOT/skills/anthropic/skills"
BATCH_ID="${BATCH_ID:-$(date +%Y%m%d_%H%M%S)}"
RESULTS_DIR="$BENCH_DIR/results/$BATCH_ID"
OUTPUTS_ROOT="$REPO_ROOT/outputs"
mkdir -p "$RESULTS_DIR"

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    echo "ERROR: OPENAI_API_KEY is not set."
    exit 1
fi

ALL_BENCHES=(
    pdf pptx xlsx docx
    internal_comms claude_api mcp_builder webapp_testing
    frontend_design algorithmic_art slack_gif theme_factory
    brand_guidelines doc_coauthoring skill_creator web_artifacts canvas_design
)

if [[ $# -gt 0 ]]; then BENCHES=("$@"); else BENCHES=("${ALL_BENCHES[@]}"); fi

PASSED=0; FAILED=0; SKIPPED=0

echo "============================================================"
echo "  Skill Benchmark Suite — batch $BATCH_ID"
echo "  Model: $(grep default_model "$BENCH_DIR/lib/jac.toml" | awk -F'"' '{print $2}')"
echo "  Results → $RESULTS_DIR"
echo "============================================================"
echo ""

for bench in "${BENCHES[@]}"; do
    file="$BENCH_DIR/baseline/${bench}_bench.jac"
    if [[ ! -f "$file" ]]; then
        echo "  [SKIP] $bench — file not found: $file"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    workdir="$OUTPUTS_ROOT/$bench/baseline/run-1"
    rm -rf "$workdir"
    mkdir -p "$workdir"

    echo "------------------------------------------------------------"
    echo "  Running: $bench   (cwd=$workdir)"
    echo "------------------------------------------------------------"

    if (
        cd "$workdir"
        SKILLS_ROOT="$SKILLS_ROOT" RESULTS_DIR="$RESULTS_DIR" \
            jac run "$file"
    ); then
        PASSED=$((PASSED + 1))
    else
        echo "  [FAILED] $bench exited with error"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

echo "============================================================"
echo "  Results: $PASSED passed / $FAILED failed / $SKIPPED skipped"
echo "  Results dir: $RESULTS_DIR"
echo "  Artifacts:   $OUTPUTS_ROOT/<skill>/baseline/run-1/"
echo "============================================================"
