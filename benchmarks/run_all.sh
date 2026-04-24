#!/usr/bin/env bash
# Run all skill benchmarks from the repo root.
# Usage:
#   ./benchmarks/run_all.sh              # run all skills
#   ./benchmarks/run_all.sh pdf pptx     # run specific skills
#
# Results are written to benchmarks/results/<skill>_breakdown.json
# Requires: OPENAI_API_KEY (or whichever provider is in jac.toml)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH_DIR="$REPO_ROOT/benchmarks"
RESULTS_DIR="$BENCH_DIR/results"
mkdir -p "$RESULTS_DIR"

cd "$REPO_ROOT"

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    echo "ERROR: OPENAI_API_KEY is not set."
    exit 1
fi

ALL_BENCHES=(
    pdf
    pptx
    xlsx
    docx
    internal_comms
    claude_api
    mcp_builder
    webapp_testing
    frontend_design
    algorithmic_art
    slack_gif
    theme_factory
    brand_guidelines
    doc_coauthoring
    skill_creator
    web_artifacts
    canvas_design
)

# If specific skills are passed as args, run only those
if [[ $# -gt 0 ]]; then
    BENCHES=("$@")
else
    BENCHES=("${ALL_BENCHES[@]}")
fi

PASSED=0
FAILED=0
SKIPPED=0

echo "============================================================"
echo "  Skill Benchmark Suite — Context Composition Analysis"
echo "  Model: $(grep default_model "$BENCH_DIR/jac.toml" | awk -F'"' '{print $2}')"
echo "  Run started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

for bench in "${BENCHES[@]}"; do
    file="$BENCH_DIR/${bench}_bench.jac"

    if [[ ! -f "$file" ]]; then
        echo "  [SKIP] $bench — file not found: $file"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo "------------------------------------------------------------"
    echo "  Running: $bench"
    echo "------------------------------------------------------------"

    # Run benchmark from repo root so skill file paths resolve correctly.
    # Move results JSON to results dir after each run.
    if jac run "$file"; then
        PASSED=$((PASSED + 1))
        # Collect any JSON output files produced in the repo root
        for f in *_breakdown.json *_results.json *_runs.jsonl; do
            [[ -f "$f" ]] && mv "$f" "$RESULTS_DIR/" 2>/dev/null || true
        done
    else
        echo "  [FAILED] $bench exited with error"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

echo "============================================================"
echo "  Results: $PASSED passed / $FAILED failed / $SKIPPED skipped"
echo "  Output → $RESULTS_DIR/"
echo "============================================================"
