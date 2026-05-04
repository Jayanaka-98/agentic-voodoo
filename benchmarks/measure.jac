"""Measurement harness for byllm benchmarks.

Monkeypatches litellm.completion directly so every ReAct iteration
is captured — not just the first call per agent invocation.

Context composition per call is decomposed into four buckets:
  system   — byLLM system persona + INSTRUCTION_TOOL boilerplate (messages[0])
  mtir     — function description + caller args, skill file lives here (messages[1])
  asst     — accumulated assistant reasoning / tool-call turns (messages[2+] role=assistant)
  tool     — accumulated tool result turns (messages[2+] role=tool/function)
"""

import time;
import json;
import os;
import patcher;
import from typing { Any }

glob _patcher: Any  = patcher;
glob _state: dict   = {"start_time": 0.0};

# ── Public API ────────────────────────────────────────────────────────────────

def setup -> None {
    _patcher.clear();
    _patcher.install();
    _state["start_time"] = time.time();
}

def show_results(label: str, success: bool = True) -> None {
    wall_ms: float = (time.time() - float(_state["start_time"])) * 1000.0;

    calls: list[Any] = list(_patcher.get_log());

    total_prompt: int     = sum([int(c["prompt_tokens"])     for c in calls]);
    total_completion: int = sum([int(c["completion_tokens"]) for c in calls]);
    total_tokens: int     = sum([int(c["total_tokens"])      for c in calls]);
    total_llm_ms: float   = sum([float(c["duration_ms"])     for c in calls]);

    status: str = "SUCCESS" if success else "FAILED";
    sep: str    = "=" * 60;

    print("");
    print(sep);
    print(f"  {label}  [{status}]");
    print(sep);
    print(f"  Wall clock time:      {int(wall_ms)} ms");
    print(f"  LLM API calls:        {len(calls)}");
    print(f"  Total LLM latency:    {int(total_llm_ms)} ms");
    print("");
    print("  --- Token Usage ---");
    print(f"  Prompt tokens:        {total_prompt}");
    print(f"  Completion tokens:    {total_completion}");
    print(f"  Total tokens:         {total_tokens}");
    print("");
    print("  --- Per LLM API Call ---");
    for (i, c) in enumerate(calls) {
        pt: int = int(c["prompt_tokens"]);
        ct: int = int(c["completion_tokens"]);
        ms: int = int(float(c["duration_ms"]));
        print(f"    [{i + 1}] {pt} in / {ct} out / {ms}ms");
    }
    print(sep);

    result: dict = {
        "label":                label,
        "success":              success,
        "wall_clock_ms":        wall_ms,
        "llm_api_calls":        len(calls),
        "total_llm_latency_ms": total_llm_ms,
        "prompt_tokens":        total_prompt,
        "completion_tokens":    total_completion,
        "total_tokens":         total_tokens,
        "per_api_call":         list(calls)
    };

    fname: str = str(label.lower().replace(" ", "_").replace("(", "").replace(")", "").replace("+", "plus"));
    with open(f"{fname}_runs.jsonl", "a") as f {
        f.write(json.dumps(result));
        f.write("\n");
    }
    with open(f"{fname}_results.json", "w") as f {
        json.dump(result, f, indent=2);
    }
}

def show_context_breakdown -> None {
    calls: list[Any] = list(_patcher.get_log());

    if not calls {
        print("  (no breakdown data)");
        return;
    }

    sep: str    = "-" * 84;
    header: str = f"  {'#':<4} {'msgs':>4} {'system':>7} {'mtir':>7} {'asst':>7} {'tool':>7} {'total':>8} {'mtir%':>6}  composition";

    print("");
    print("  === Context Composition Per API Call (tiktoken monkeypatch) ===");
    print(header);
    print(f"  {sep}");

    for c in calls {
        idx: int    = int(c["call_index"]) + 1;
        msgs: int   = int(c["message_count"]);
        b: Any      = c["breakdown"];
        sys_t: int  = int(b["system"]);
        mtir_t: int = int(b["mtir"]);
        asst_t: int = int(b["asst"]);
        tool_t: int = int(b["tool"]);
        total: int  = int(b["total"]);
        pct: float  = float(b["mtir_pct"]);

        bar: str = "";
        if total > 0 {
            w: int  = 28;
            sw: int = int(sys_t  / total * w);
            mw: int = int(mtir_t / total * w);
            aw: int = int(asst_t / total * w);
            tw: int = max(0, w - sw - mw - aw);
            bar = "S" * sw + "M" * mw + "A" * aw + "T" * tw;
        }

        print(f"  [{idx:>2}] {msgs:>4} {sys_t:>7} {mtir_t:>7} {asst_t:>7} {tool_t:>7} {total:>8} {pct:>5.1f}%  |{bar}|");
    }

    print(f"  {sep}");
    print("  S=system  M=mtir(skill+args)  A=asst(reasoning)  T=tool(results)");

    with open("context_breakdown.json", "w") as f {
        json.dump({"per_call_breakdown": list(calls)}, f, indent=2);
    }
    print("  Saved -> context_breakdown.json");
}
