"""Measurement harness — wraps an agent run with the litellm patcher.

Output:
  - <results_dir>/<label>_runs.jsonl   one JSON per run, full transcripts included
  - <results_dir>/<label>_results.json overwritten with the latest run summary
  - <results_dir>/context_breakdown.json  (only if show_context_breakdown is called)
"""

import json;
import os;
import time;
import from voodoo_bench { patcher }


glob _state: dict = {"start_time": 0.0, "label": ""};


"""Install the patcher and start the wall-clock timer for `label`."""
def setup(label: str = "run") -> None {
    patcher.clear();
    patcher.install();
    _state["start_time"] = time.time();
    _state["label"] = label;
}


"""Restore litellm to its original state."""
def teardown() -> None {
    patcher.uninstall();
}


"""Print the run summary, dump JSONL/JSON artifacts, return the result dict."""
def show_results(label: str = "", success: bool = True) -> dict {
    wall_ms: float = (time.time() - float(_state["start_time"])) * 1000.0;
    calls: list = list(patcher.get_log());

    total_prompt: int     = sum([int(c["prompt_tokens"])     for c in calls]);
    total_completion: int = sum([int(c["completion_tokens"]) for c in calls]);
    total_tokens: int     = sum([int(c["total_tokens"])      for c in calls]);
    total_llm_ms: float   = sum([float(c["duration_ms"])     for c in calls]);

    label = label or str(_state.get("label") or "run");
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
        "per_api_call":         calls,
    };

    fname: str = (
        label.lower()
        .replace(" ", "_")
        .replace("(", "")
        .replace(")", "")
        .replace("+", "plus")
    );
    rdir: str = os.environ.get("RESULTS_DIR", ".");
    os.makedirs(rdir, exist_ok=True);
    with open(f"{rdir}/{fname}_runs.jsonl", "a") as f {
        f.write(json.dumps(result));
        f.write("\n");
    }
    with open(f"{rdir}/{fname}_results.json", "w") as f {
        json.dump(result, f, indent=2);
    }
    return result;
}


"""Print the per-call context-bucket composition table and dump JSON."""
def show_context_breakdown() -> None {
    calls: list = list(patcher.get_log());
    if not calls {
        print("  (no breakdown data)");
        return;
    }

    sep: str    = "-" * 84;
    header: str = (
        f"  {'#':<4} {'msgs':>4} {'system':>7} {'mtir':>7} "
        + f"{'asst':>7} {'tool':>7} {'total':>8} {'mtir%':>6}  composition"
    );
    print("");
    print("  === Context Composition Per API Call ===");
    print(header);
    print(f"  {sep}");

    for c in calls {
        idx: int    = int(c["call_index"]) + 1;
        msgs: int   = int(c["message_count"]);
        b: dict     = c["breakdown"];
        sys_t: int  = int(b["system"]);
        mtir_t: int = int(b["mtir"]);
        asst_t: int = int(b["asst"]);
        tool_t: int = int(b["tool"]);
        total: int  = int(b["total"]);
        pct: float  = float(b["mtir_pct"]);
        bar: str    = "";
        if total > 0 {
            w: int  = 28;
            sw: int = int(sys_t  / total * w);
            mw: int = int(mtir_t / total * w);
            aw: int = int(asst_t / total * w);
            tw: int = max(0, w - sw - mw - aw);
            bar = "S" * sw + "M" * mw + "A" * aw + "T" * tw;
        }
        print(
            f"  [{idx:>2}] {msgs:>4} {sys_t:>7} {mtir_t:>7} {asst_t:>7} "
            + f"{tool_t:>7} {total:>8} {pct:>5.1f}%  |{bar}|"
        );
    }

    print(f"  {sep}");
    print("  S=system  M=mtir(skill+args)  A=asst(reasoning)  T=tool(results)");

    rdir: str = os.environ.get("RESULTS_DIR", ".");
    os.makedirs(rdir, exist_ok=True);
    with open(f"{rdir}/context_breakdown.json", "w") as f {
        json.dump({"per_call_breakdown": calls}, f, indent=2);
    }
    print(f"  Saved -> {rdir}/context_breakdown.json");
}
