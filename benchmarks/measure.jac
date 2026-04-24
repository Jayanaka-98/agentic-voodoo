"""Measurement harness for byllm benchmarks.

Hooks into litellm CustomLogger to capture per-API-call token usage,
latency, and context composition. Uses tiktoken for exact token counts
and decomposes each prompt into four buckets:

  system   — byLLM system persona + INSTRUCTION_TOOL boilerplate (messages[0])
  mtir     — function description + caller args, skill file content lives here (messages[1])
  asst     — accumulated assistant reasoning / tool-call turns (messages[2+] role=assistant)
  tool     — accumulated tool result turns (messages[2+] role=tool/function)
"""

import time;
import json;
import os;
import litellm;
import from typing { Any }
import from litellm.integrations.custom_logger { CustomLogger }

# ── Internal state ──
glob _llm_api_calls: list[Any]      = [],
     _pre_call_snapshots: list[Any] = [],
     _state: dict                   = {"start_time": 0.0};

# ── Tiktoken helpers ──

def _get_encoding(model: str) -> Any {
    import tiktoken;
    try {
        return tiktoken.encoding_for_model(model);
    } except Exception {
        return tiktoken.get_encoding("cl100k_base");
    }
}

def _tokens_for_message(msg: dict, enc: Any) -> int {
    # 4-token overhead per message (role separator + framing) per tiktoken cookbook
    total: int  = 4;
    content: Any = msg.get("content", "") or "";
    if isinstance(content, list) {
        for block in content {
            b: Any    = block;
            if isinstance(b, dict) {
                text: str = str(b.get("text") or b.get("content") or "");
            } else {
                text: str = str(b);
            }
            total += len(enc.encode(text));
        }
    } else {
        total += len(enc.encode(str(content)));
    }
    tool_calls: Any = msg.get("tool_calls");
    if tool_calls {
        total += len(enc.encode(json.dumps(tool_calls)));
    }
    return total;
}

def _categorize_messages(messages: list[dict], enc: Any) -> dict {
    system_t: int = 0;
    mtir_t: int   = 0;
    asst_t: int   = 0;
    tool_t: int   = 0;
    for (i, msg) in enumerate(messages) {
        role: str = str(msg.get("role", ""));
        t: int    = _tokens_for_message(msg, enc);
        if i == 0 {
            system_t += t;
        } elif i == 1 {
            mtir_t += t;
        } elif role == "assistant" {
            asst_t += t;
        } elif role in ("tool", "function") {
            tool_t += t;
        } else {
            mtir_t += t;
        }
    }
    total: int = system_t + mtir_t + asst_t + tool_t;
    return {
        "system": system_t,
        "mtir":   mtir_t,
        "asst":   asst_t,
        "tool":   tool_t,
        "total":  total
    };
}

# ── LiteLLM callback ──

obj TokenTracker(CustomLogger) {
    def log_pre_api_call(model: str, messages: list[dict], kwargs: dict) -> None {
        enc: Any         = _get_encoding(model);
        breakdown: dict  = _categorize_messages(messages, enc);
        meta: Any        = kwargs.get("metadata") or {};
        caller_name: str = str(meta.get("jac_caller_name", "unknown"));
        _pre_call_snapshots.append({
            "call_index":    len(_pre_call_snapshots),
            "model":         model,
            "caller_name":   caller_name,
            "breakdown":     breakdown,
            "message_count": len(messages)
        });
    }

    def log_success_event(kwargs: dict, response_obj: Any, start_time: Any, end_time: Any) -> None {
        usage: Any             = getattr(response_obj, "usage", None);
        prompt_tokens: int     = int(getattr(usage, "prompt_tokens",     0) or 0);
        completion_tokens: int = int(getattr(usage, "completion_tokens", 0) or 0);
        total_tokens: int      = int(getattr(usage, "total_tokens",      0) or 0);
        delta: Any             = getattr(end_time, "__sub__")(start_time);
        duration_ms: float     = float(getattr(delta, "total_seconds")()) * 1000.0;
        _llm_api_calls.append({
            "model":             str(kwargs.get("model", "unknown")),
            "prompt_tokens":     prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens":      total_tokens,
            "duration_ms":       duration_ms
        });
    }
}

# ── Public API ──

def setup -> None {
    _llm_api_calls.clear();
    _pre_call_snapshots.clear();
    _state["start_time"] = time.time();
    litellm.callbacks = [TokenTracker()];
}

def show_results(label: str, success: bool = True) -> None {
    wall_ms: float = (time.time() - float(_state["start_time"])) * 1000.0;

    total_prompt: int     = sum([int(c["prompt_tokens"])     for c in _llm_api_calls]);
    total_completion: int = sum([int(c["completion_tokens"]) for c in _llm_api_calls]);
    total_tokens: int     = sum([int(c["total_tokens"])      for c in _llm_api_calls]);
    total_llm_ms: float   = sum([float(c["duration_ms"])     for c in _llm_api_calls]);

    status: str = "SUCCESS" if success else "FAILED";
    sep: str    = "=" * 60;

    print("");
    print(sep);
    print(f"  {label}  [{status}]");
    print(sep);
    print(f"  Wall clock time:      {int(wall_ms)} ms");
    print(f"  LLM API calls:        {len(_llm_api_calls)}");
    print(f"  Total LLM latency:    {int(total_llm_ms)} ms");
    print("");
    print("  --- Token Usage ---");
    print(f"  Prompt tokens:        {total_prompt}");
    print(f"  Completion tokens:    {total_completion}");
    print(f"  Total tokens:         {total_tokens}");
    print("");
    print("  --- Per LLM API Call ---");
    for (i, c) in enumerate(_llm_api_calls) {
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
        "llm_api_calls":        len(_llm_api_calls),
        "total_llm_latency_ms": total_llm_ms,
        "prompt_tokens":        total_prompt,
        "completion_tokens":    total_completion,
        "total_tokens":         total_tokens,
        "per_api_call":         list(_llm_api_calls)
    };

    run_id: str     = str(os.environ.get("RUN_ID", "0") or "0");
    fname: str      = str(label.lower().replace(" ", "_").replace("(", "").replace(")", "").replace("+", "plus"));
    jsonl_path: str = f"{fname}_runs.jsonl";
    with open(jsonl_path, "a") as f {
        f.write(json.dumps(result));
        f.write("\n");
    }
    with open(f"{fname}_results.json", "w") as f {
        json.dump(result, f, indent=2);
    }
}

def show_context_breakdown -> None {
    if not _pre_call_snapshots {
        print("  (no breakdown data)");
        return;
    }

    sep: str    = "-" * 80;
    header: str = f"  {'#':<4} {'caller':<22} {'system':>7} {'mtir':>7} {'asst':>7} {'tool':>7} {'est_total':>10}  composition";

    print("");
    print("  === Context Composition Per API Call (tiktoken) ===");
    print(header);
    print(f"  {sep}");

    for snap in _pre_call_snapshots {
        idx: int    = int(snap["call_index"]) + 1;
        caller: str = str(snap["caller_name"])[:20];
        b: Any      = snap["breakdown"];
        sys_t: int  = int(b["system"]);
        mtir_t: int = int(b["mtir"]);
        asst_t: int = int(b["asst"]);
        tool_t: int = int(b["tool"]);
        est: int    = int(b["total"]);

        bar: str = "";
        if est > 0 {
            w: int     = 32;
            sys_w: int = int(sys_t  / est * w);
            mtr_w: int = int(mtir_t / est * w);
            ast_w: int = int(asst_t / est * w);
            tol_w: int = max(0, w - sys_w - mtr_w - ast_w);
            bar = "S" * sys_w + "M" * mtr_w + "A" * ast_w + "T" * tol_w;
        }

        print(f"  [{idx:>2}] {caller:<22} {sys_t:>7} {mtir_t:>7} {asst_t:>7} {tool_t:>7} {est:>10}  |{bar}|");
    }

    print(f"  {sep}");
    print("  S=system  M=mtir(skill+args)  A=asst(reasoning)  T=tool(results)");

    with open("context_breakdown.json", "w") as f {
        json.dump({"per_call_breakdown": list(_pre_call_snapshots)}, f, indent=2);
    }
    print("  Saved -> context_breakdown.json");
}
