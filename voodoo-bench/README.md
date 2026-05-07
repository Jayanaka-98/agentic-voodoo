# voodoo-bench

A CLI bench runner for Jac/byLLM agents. Point it at any agent directory, swap
models freely (provider APIs or a local vLLM server), and capture every
prompt and completion.

## Install

```bash
pip install voodoo-bench
```

This pulls in `jaseci` (which brings `jaclang` + `byllm`), `litellm`, and
`tiktoken`. The litellm monkeypatch that captures LLM calls is applied **only
when the CLI runs** — `import voodoo_bench` is inert.

## Quick start

```bash
voodoo-bench register pdf ./examples/pdf_agent
voodoo-bench list

# Provider API
voodoo-bench run pdf --model anthropic/claude-opus-4-7

# Local vLLM (any OpenAI-compatible endpoint)
voodoo-bench run pdf \
  --model vllm:Qwen/Qwen2.5-72B-Instruct \
  --base-url http://localhost:8000/v1

# Print every prompt and completion to stderr as they happen
voodoo-bench run pdf --model openai/gpt-4o --verbose
```

## Agent contract

An agent is a directory containing **either** a `voodoo-bench.toml` manifest
**or** an `agent.jac` file with the required symbols.

```
my-agent/
├── agent.jac              # def run(task: str, llm: Model, skill: str) -> str
├── SKILL.md               # default skill text (optional)
└── voodoo-bench.toml      # optional manifest: name, default_skill, default_task
```

`run(task, llm, skill)` is called by the CLI. Pass the `llm` arg through to your
`by llm(model=llm, ...)` decorator so each invocation uses the model the user
selected on the command line.

## What gets captured

Every `litellm.completion` call (every ReAct iteration) lands in
`<results_dir>/<label>_runs.jsonl` with:

- model, message_count, duration_ms
- prompt / completion / total tokens
- context-bucket breakdown (system / mtir / asst / tool)
- **input_messages**: full prompt text per role
- **output**: assistant content + tool_calls

Use `--verbose` to also stream them to stderr in real time, and
`--context-breakdown` for the per-call composition table.

## Discovery

```bash
voodoo-bench discover ./agents/         # walk and register all conforming dirs
voodoo-bench discover ./agents/ --dry-run
```

Registry lives at `~/.voodoo-bench/registry.toml` (override with
`$VOODOO_BENCH_HOME`).
