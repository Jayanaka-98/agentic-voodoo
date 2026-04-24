# agentic-voodoo

Research repository investigating **Object-Spatial Programming (OSP)** as a better substrate for AI agent skills — and measuring the cost of the current `skills.md` paradigm in concrete terms.

## Thesis

A `SKILL.md` file is a program written in the wrong language. It collapses four fundamentally different concerns into a single prose document:

| Layer | What it encodes | Right substrate |
|---|---|---|
| Workflow structure | Step ordering, branching | Graph topology |
| Output contracts | Return types, schemas | Type system |
| Semantic guidance | LLM reasoning hints | Scoped `sem` annotations |
| Safety invariants | Cross-cutting rules | Code-enforced logic |

When everything lives in prose, the LLM must interpret all four layers on every API call. This has measurable consequences: the skill text stays in context for every ReAct iteration, compounding token cost and latency as the conversation grows.

The proposed alternative — encoding skills in [Jac](https://github.com/Jaseci-Labs/jaseci) with the [byLLM](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm) plugin — separates each layer into its proper substrate. Each `by llm()` call only sees the minimal scoped context for its node in the workflow graph.

**Empirical results** (5 runs each, `gpt-4o-mini`, healthcheck skill):

| Metric | skills.md baseline | OSP + byLLM | Improvement |
|---|---|---|---|
| Avg prompt tokens | 7,698 | 2,497 | **−68%** |
| Avg wall time | 140 s | 27 s | **5× faster** |
| Avg cost | $0.00124 | $0.00099 | **−20%** |
| Success rate | 100% | 100% | — |

The token reduction is structural, not incidental: in the baseline, the full skill text is present in every ReAct iteration's context window. In OSP, each node only injects the tokens it needs for its specific step.

---

## Repository Structure

```
agentic-voodoo/
├── examples/
│   ├── skills_md_is_a_program.md      # Core research argument
│   ├── healthcheck_skill.md           # Real-world skill from OpenClaw (246 lines)
│   ├── healthcheck_byllm_osp.jac      # OSP reimplementation (7-node typed graph)
│   ├── summarize_skill.md             # Simpler skill example
│   ├── summarize_byllm_osp.jac        # OSP reimplementation
│   └── experiment/                    # Controlled benchmark (healthcheck)
│       ├── baseline.jac               # skills.md approach: one big by llm() call
│       ├── osp.jac                    # OSP approach: five scoped by llm() calls
│       ├── measure.jac                # Measurement harness (litellm + tiktoken)
│       ├── mock_tools.jac             # Reproducible system tool stubs
│       ├── aggregate_results.json     # Aggregated results (5 runs each)
│       └── run.sh / run_multi.sh      # Experiment runners
│
├── benchmarks/                        # Per-skill baseline benchmark suite
│   ├── tools.jac                      # Real execution tools (no mocking)
│   ├── measure.jac                    # Context composition measurement harness
│   ├── jac.toml                       # Model config (gpt-4o-mini, temp=0)
│   ├── run_all.sh                     # Run all or selected skills
│   ├── pdf_bench.jac
│   ├── pptx_bench.jac
│   ├── xlsx_bench.jac
│   ├── docx_bench.jac
│   ├── internal_comms_bench.jac
│   ├── claude_api_bench.jac
│   ├── mcp_builder_bench.jac
│   ├── webapp_testing_bench.jac
│   ├── frontend_design_bench.jac
│   ├── algorithmic_art_bench.jac
│   ├── slack_gif_bench.jac
│   ├── theme_factory_bench.jac
│   ├── brand_guidelines_bench.jac
│   ├── doc_coauthoring_bench.jac
│   ├── skill_creator_bench.jac
│   ├── web_artifacts_bench.jac
│   └── canvas_design_bench.jac
│
└── skills/                            # Submodule: github.com/anthropics/skills
```

---

## The Benchmark Suite

The `benchmarks/` directory contains end-to-end baseline measurements for all 17 skills in the [anthropics/skills](https://github.com/anthropics/skills) repository. Each benchmark:

1. Loads the full `SKILL.md` as a function argument (injecting it into MTIR — `messages[1]`)
2. Gives the agent a realistic end-to-end task (e.g. *"Create a 5-slide pitch deck for GreenFlow..."*)
3. Runs a real ReAct loop with real tool execution — no mocking
4. Measures **context composition** at every API call using tiktoken

### What is measured

At each `by llm()` API call, the harness decomposes the prompt into four buckets:

```
Call [3]  run_task              system    388   mtir   8,241   asst    612   tool   2,180   est   11,421  |SMMMMMMMMMMMMMMMMMMMMMAATTTTT|
          ^                     ^                ^              ^             ^
          ReAct iteration       byLLM boilerplate  skill file    model turns   tool results
```

- **system** — byLLM's system persona + `INSTRUCTION_TOOL` boilerplate (fixed)
- **mtir** — function description + caller args, including the full skill file text (fixed per call)
- **asst** — accumulated assistant reasoning and tool-call turns (grows each iteration)
- **tool** — accumulated tool result turns (grows each iteration)

This reveals the **skill bloat ratio**: what fraction of every token budget is consumed by the skill file itself before any task-specific content is even considered.

### Correctness evaluation

Each benchmark run checks three layers:

| Layer | What is checked |
|---|---|
| Execution | Agent completed without exception |
| Artifact presence | Expected output file exists on disk |
| Artifact size | File exceeds a per-skill minimum (rules out empty/stub outputs) |

With real tools, the agent receives genuine error messages from failed code execution and can self-correct — producing an authentic multi-step trace rather than a simulated one.

### Skill inventory

| Skill | Task type | Key tools | Expected artifact |
|---|---|---|---|
| `pdf` | Document creation | Python (reportlab/pypdf) | `.pdf` |
| `pptx` | Presentation creation | Python-pptx / pptxgenjs | `.pptx` |
| `xlsx` | Spreadsheet modeling | pandas / openpyxl | `.xlsx` |
| `docx` | Document creation | docx (JS) | `.docx` |
| `internal-comms` | Text generation | write_file | `.md` |
| `claude-api` | Code generation | Python | `.py` |
| `mcp-builder` | Server development | Python (FastMCP) | `.py` |
| `webapp-testing` | Test suite writing | Python (Playwright) | `.py` |
| `frontend-design` | UI development | HTML/CSS | `.html` |
| `algorithmic-art` | Generative art | p5.js | `.js` |
| `slack-gif-creator` | Image generation | Python (PIL) | `.gif` |
| `theme-factory` | Config generation | write_file | `.json` |
| `brand-guidelines` | Document creation | write_file | `.md` |
| `doc-coauthoring` | Document editing | write_file | `.md` |
| `skill-creator` | Skill authoring | write_file | `SKILL.md` |
| `web-artifacts-builder` | React app bundling | bash (npm) | `.html` |
| `canvas-design` | Visual design | Python / write_file | `.md` + `.pdf` |

### Running benchmarks

```bash
# Prerequisites
export OPENAI_API_KEY=sk-...   # or whichever provider is in jac.toml
pip install jaclang byllm tiktoken litellm

# Single skill (from repo root)
jac run benchmarks/pdf_bench.jac

# All skills
./benchmarks/run_all.sh

# Selected skills
./benchmarks/run_all.sh pdf pptx xlsx
```

Results are written to `benchmarks/results/`. Each run produces:
- `*_results.json` — aggregate token/latency summary
- `*_runs.jsonl` — per-run records for multi-run aggregation
- `context_breakdown.json` — per-API-call context composition

---

## The Core Experiment

The controlled experiment in `examples/experiment/` isolates the comparison on a single skill (host security healthcheck from [OpenClaw](https://github.com/Jaseci-Labs/openclaw)) to eliminate confounding variables.

**Baseline** (`baseline.jac`): one `by llm()` call with the full 246-line skill embedded in the prompt. The skill text remains in context for every ReAct iteration.

**OSP** (`osp.jac`): five scoped `by llm()` functions, each receiving only the typed inputs for their specific step. No skill prose — workflow is enforced by graph topology and return types.

```bash
cd examples/experiment
export OPENAI_API_KEY=sk-...
./run.sh          # single run, side-by-side comparison
./run_multi.sh    # 5 runs each for aggregate stats
python compare.py
```