# Benchmark Run — Index
**Timestamp:** 2026-04-24 16:02:18

## Files in this directory

| File | Description |
|---|---|
| `summary.md` | Full analysis: pass/fail table, token usage, context composition, key findings |
| `per_skill.md` | Per-skill breakdown with metrics and notes |
| `*.log` | Raw stdout captured from each benchmark run |
| `*_context_breakdown.json` | Per-call MTIR/system/asst/tool token breakdown (tiktoken) |
| `*_results.json` | Aggregate token/latency summary per skill |
| `*_runs.jsonl` | Per-run JSONL records |

## Quick stats

- **17 skills** run
- **7 clean passes** (internal-comms, brand-guidelines†, doc-coauthoring, docx, mcp-builder, skill-creator, claude-api, canvas-design)
- **9 threshold misses** — artifacts produced but size floors were too conservative
- **1 task failure** — web-artifacts (30-iteration ReAct loop exhausted before bundling)
- **MTIR dominance:** skill file occupies **86–99%** of every initial prompt
- **Token range:** 1,995 (internal-comms) → 642,250 (mcp-builder)
- **Costliest run:** mcp-builder — 23 calls, 642K prompt tokens

† brand-guidelines measured 3.0 KB vs 3.0 KB threshold — rounding artifact, treat as pass.
