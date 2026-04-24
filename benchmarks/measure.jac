"""Measurement harness for comparing byllm approaches.

Hooks into litellm CustomLogger to capture per-API-call token usage,
latency, and context composition. Uses tiktoken for exact token counts
and decomposes each prompt into four buckets:

  system   — byLLM system persona + INSTRUCTION_TOOL boilerplate (messages[0])
  mtir     — function description + caller args, where skill file content lives (messages[1])
  asst     — accumulated assistant reasoning / tool-call turns (messages[2+] role=assistant)
  tool     — accumulated tool result turns (messages[2+] role=tool/function)
"""

import time;
import json;
import os;
import tiktoken;
import litellm;
import from typing { Any }
import from litellm.integrations.custom_logger { CustomLogger }

# ── Internal state ──
glob _llm_api_calls: list = [],
     _pre_call_snapshots: list = [],
     _state: dict = {"start_time": 0.0};

# ── Tiktoken helpers ──

def _get_encoding(model: str) -> Any {
    try {
        return tiktoken.encoding_for_model(model);
    } except Exception {
        return tiktoken.get_encoding("cl100k_base");
    }
}

def _tokens_for_message(msg: dict, enc: Any) -> int {
    # 4-token overhead per message (role separator + framing) per tiktoken cookbook
    total = 4;
    content = msg.get("content", "") or "";
    if isinstance(content, list) {
        for block in content {
            if isinstance(block, dict) {
                text = block.get("text") or block.get("content") or "";
                total += len(enc.encode(str(text)));
            } else {
                total += len(enc.encode(str(block)));
            }
        }
    } else {
        total += len(enc.encode(str(content)));
    }
    tool_calls = msg.get("tool_calls");
    if tool_calls {
        total += len(enc.encode(json.dumps(tool_calls)));
    }
    return total;
}

def _categorize_messages(messages: list, enc: Any) -> dict {
    system_t = 0;
    mtir_t = 0;
    asst_t = 0;
    tool_t = 0;

    for (i, msg) in enumerate(messages) {
        role = msg.get("role", "");
        t = _tokens_for_message(msg, enc);
        if i == 0 {
            system_t += t;
        } elif i == 1 {
            mtir_t += t;
        } elif role == "assistant" {
            asst_t += t;
        } elif role in ("tool", "function") {
            tool_t += t;
        } else {
            # Extra user messages injected mid-loop (e.g. recovery prompts)
            mtir_t += t;
        }
    }

    total = system_t + mtir_t + asst_t + tool_t;
    return {
        "system": system_t,
        "mtir": mtir_t,
        "asst": asst_t,
        "tool": tool_t,
        "total": total
    };
}

# ── LiteLLM callback ──

class TokenTracker(CustomLogger) {
    def log_pre_api_call(self: TokenTracker, model: str, messages: list, kwargs: dict) -> None {
        enc = _get_encoding(model);
        breakdown = _categorize_messages(messages, enc);
        caller_name = (kwargs.get("metadata") or {}).get("jac_caller_name", "unknown");
        _pre_call_snapshots.append({
            "call_index": len(_pre_call_snapshots),
            "model": model,
            "caller_name": caller_name,
            "breakdown": breakdown,
            "message_count": len(messages)
        });
    }

    def log_success_event(
        self, kwargs: dict, response_obj: object, start_time: object, end_time: object
    ) -> None {
        usage = getattr(response_obj, "usage", None);
        prompt_tokens = getattr(usage, "prompt_tokens", 0) or 0;
        completion_tokens = getattr(usage, "completion_tokens", 0) or 0;
        total_tokens = getattr(usage, "total_tokens", 0) or 0;
        duration_ms = (end_time - start_time).total_seconds() * 1000;
        _llm_api_calls.append({
            "model": kwargs.get("model", "unknown"),
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens": total_tokens,
            "duration_ms": round(duration_ms, 1)
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
    wall_ms = (time.time() - _state["start_time"]) * 1000;

    total_prompt = sum([c["prompt_tokens"] for c in _llm_api_calls]);
    total_completion = sum([c["completion_tokens"] for c in _llm_api_calls]);
    total_tokens = sum([c["total_tokens"] for c in _llm_api_calls]);
    total_llm_ms = sum([c["duration_ms"] for c in _llm_api_calls]);

    status = "SUCCESS" if success else "FAILED";
    sep = "=" * 60;

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
        pt = c["prompt_tokens"];
        ct = c["completion_tokens"];
        ms = int(c["duration_ms"]);
        print(f"    [{i + 1}] {pt} in / {ct} out / {ms}ms");
    }
    print(sep);

    result = {
        "label": label,
        "success": success,
        "wall_clock_ms": round(wall_ms, 1),
        "llm_api_calls": len(_llm_api_calls),
        "total_llm_latency_ms": round(total_llm_ms, 1),
        "prompt_tokens": total_prompt,
        "completion_tokens": total_completion,
        "total_tokens": total_tokens,
        "per_api_call": list(_llm_api_calls)
    };

    run_id = os.environ.get("RUN_ID", "0");
    fname = label.lower().replace(" ", "_").replace("(", "").replace(")", "").replace(
        "+", "plus"
    );
    jsonl_path = f"{fname}_runs.jsonl";
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

    sep = "-" * 80;
    header = f"  {'#':<4} {'caller':<22} {'system':>7} {'mtir':>7} {'asst':>7} {'tool':>7} {'est_total':>10}  composition";

    print("");
    print("  === Context Composition Per API Call (tiktoken) ===");
    print(header);
    print(f"  {sep}");

    for snap in _pre_call_snapshots {
        idx = snap["call_index"] + 1;
        caller = snap["caller_name"][:20];
        b = snap["breakdown"];
        sys_t = b["system"];
        mtir_t = b["mtir"];
        asst_t = b["asst"];
        tool_t = b["tool"];
        est = b["total"];

        if est > 0 {
            w = 32;
            sys_w  = round(sys_t  / est * w);
            mtir_w = round(mtir_t / est * w);
            asst_w = round(asst_t / est * w);
            tool_w = max(0, w - sys_w - mtir_w - asst_w);
            bar = "S" * sys_w + "M" * mtir_w + "A" * asst_w + "T" * tool_w;
        } else {
            bar = "";
        }

        print(f"  [{idx:>2}] {caller:<22} {sys_t:>7} {mtir_t:>7} {asst_t:>7} {tool_t:>7} {est:>10}  |{bar}|");
    }

    print(f"  {sep}");
    print("  S=system  M=mtir(skill+args)  A=asst(reasoning)  T=tool(results)");

    with open("context_breakdown.json", "w") as f {
        json.dump({"per_call_breakdown": list(_pre_call_snapshots)}, f, indent=2);
    }
    print("  Saved → context_breakdown.json");
}
