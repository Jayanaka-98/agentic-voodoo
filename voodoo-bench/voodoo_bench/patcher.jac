"""Monkeypatch litellm.completion / acompletion to capture every LLM call.

Captures, per call:
  - model, message_count, duration_ms
  - prompt / completion / total tokens (from response.usage)
  - context-bucket breakdown (system / mtir / asst / tool) via tiktoken
  - input_messages: full prompt messages list (raw)
  - output: { content, tool_calls } from response.choices[0].message
"""

import json;
import sys;
import time;
import litellm;
import tiktoken;

glob _log: list[dict] = [];
glob _orig_completion: any = None;
glob _orig_acompletion: any = None;
glob _installed: bool = False;
glob _verbose: bool = False;


# ── Tiktoken helpers ─────────────────────────────────────────────────────────

"""Best-effort tiktoken encoder for the given model id."""
def _enc(model: str) -> any {
    try {
        return tiktoken.encoding_for_model(model);
    } except Exception {
        return tiktoken.get_encoding("cl100k_base");
    }
}


"""Serialise an arbitrary value to JSON, falling back gracefully for Pydantic."""
def _serialize(value: any) -> str {
    try {
        return json.dumps(value);
    } except (TypeError, ValueError) {}
    if isinstance(value, list) {
        parts: list[any] = [];
        for item in value {
            if hasattr(item, "model_dump") {
                parts.append(item.model_dump());
            } elif hasattr(item, "__dict__") {
                parts.append(vars(item));
            } else {
                parts.append(str(item));
            }
        }
        try {
            return json.dumps(parts);
        } except Exception {}
    }
    return str(value);
}


"""Token count for one message including 4-token framing overhead."""
def _count_message(msg: dict[str, any], enc: any) -> int {
    total: int = 4;
    content: any = msg.get("content", "") or "";
    if isinstance(content, list) {
        for block in content {
            if isinstance(block, dict) {
                text = str(block.get("text") or block.get("content") or "");
            } else {
                text = str(block);
            }
            total += len(enc.encode(text));
        }
    } else {
        total += len(enc.encode(str(content)));
    }
    tool_calls = msg.get("tool_calls");
    if tool_calls {
        total += len(enc.encode(_serialize(tool_calls)));
    }
    return total;
}


"""Bucket message tokens into system / mtir / asst / tool."""
def _categorize(messages: list[dict[str, any]], enc: any) -> dict[str, any] {
    system_t: int = 0;
    mtir_t: int = 0;
    asst_t: int = 0;
    tool_t: int = 0;
    for (i, msg) in enumerate(messages) {
        t = _count_message(msg, enc);
        role = msg.get("role", "");
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
    total = system_t + mtir_t + asst_t + tool_t;
    return {
        "system":   system_t,
        "mtir":     mtir_t,
        "asst":     asst_t,
        "tool":     tool_t,
        "total":    total,
        "mtir_pct": round(mtir_t / total * 100, 1) if total else 0,
    };
}


"""Convert messages to plain-dict form for JSONL serialisation."""
def _normalize_messages(messages: list[any]) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    for m in messages {
        if isinstance(m, dict) {
            out.append(m);
        } elif hasattr(m, "model_dump") {
            out.append(m.model_dump());
        } elif hasattr(m, "__dict__") {
            out.append({k: v for (k, v) in vars(m).items() if not k.startswith("_")});
        } else {
            out.append({"role": "unknown", "content": str(m)});
        }
    }
    return out;
}


"""Pull content + tool_calls out of a litellm response into a JSON-safe dict."""
def _extract_output(response: any) -> dict[str, any] {
    try {
        choice = response.choices[0];
        msg = getattr(choice, "message", None) or {};
        if isinstance(msg, dict) {
            content = msg.get("content");
            tool_calls = msg.get("tool_calls");
        } else {
            content = getattr(msg, "content", None);
            tool_calls = getattr(msg, "tool_calls", None);
        }
        if tool_calls is not None {
            try {
                tool_calls = json.loads(_serialize(tool_calls));
            } except Exception {
                tool_calls = _serialize(tool_calls);
            }
        }
        return {"content": content, "tool_calls": tool_calls};
    } except Exception as e {
        return {"content": None, "tool_calls": None, "extract_error": str(e)};
    }
}


"""Pretty-print a single captured LLM call to stderr."""
def _print_call(rec: dict[str, any]) {
    idx = rec["call_index"] + 1;
    sep = "─" * 72;
    print(f"\n{sep}", file=sys.stderr);
    print(
        f"  LLM call #{idx}  model={rec['model']}  "
        + f"in={rec['prompt_tokens']} out={rec['completion_tokens']} "
        + f"({rec['duration_ms']:.0f}ms)",
        file=sys.stderr
    );
    print(sep, file=sys.stderr);
    for m in rec["input_messages"] {
        role = m.get("role", "?");
        content = m.get("content", "") or "";
        if isinstance(content, list) {
            content = _serialize(content);
        }
        print(f"\n  ── {role} ──", file=sys.stderr);
        print(str(content), file=sys.stderr);
        if m.get("tool_calls") {
            print(f"  tool_calls: {_serialize(m['tool_calls'])}", file=sys.stderr);
        }
    }
    print("\n  ── output ──", file=sys.stderr);
    out = rec["output"];
    if out.get("content") {
        print(str(out["content"]), file=sys.stderr);
    }
    if out.get("tool_calls") {
        print(f"  tool_calls: {_serialize(out['tool_calls'])}", file=sys.stderr);
    }
    print(sep + "\n", file=sys.stderr);
}


"""Append one captured LLM call to the log."""
def _record(kwargs: dict[str, any], response: any, duration_ms: float) {
    messages = list(kwargs.get("messages") or []);
    model = str(kwargs.get("model") or "unknown");
    enc = _enc(model);
    breakdown = _categorize(messages, enc);
    usage = getattr(response, "usage", None);
    rec: dict[str, any] = {
        "call_index":        len(_log),
        "model":             model,
        "message_count":     len(messages),
        "breakdown":         breakdown,
        "prompt_tokens":     int(getattr(usage, "prompt_tokens", 0) or 0),
        "completion_tokens": int(getattr(usage, "completion_tokens", 0) or 0),
        "total_tokens":      int(getattr(usage, "total_tokens", 0) or 0),
        "duration_ms":       round(duration_ms, 1),
        "input_messages":    _normalize_messages(messages),
        "output":            _extract_output(response),
    };
    _log.append(rec);
    if _verbose {
        _print_call(rec);
    }
}


# ── Patch factories ──────────────────────────────────────────────────────────

"""Wrap a sync litellm.completion-style callable so every call is logged."""
def _make_sync_patch(original: any) -> any {
    def patched(*args: any, **kwargs: any) -> any {
        t0 = time.time();
        response = original(*args, **kwargs);
        _record(kwargs, response, (time.time() - t0) * 1000.0);
        return response;
    }
    return patched;
}


"""Wrap an async litellm.acompletion-style callable so every call is logged."""
def _make_async_patch(original: any) -> any {
    async def patched(*args: any, **kwargs: any) -> any {
        t0 = time.time();
        response = await original(*args, **kwargs);
        _record(kwargs, response, (time.time() - t0) * 1000.0);
        return response;
    }
    return patched;
}


# ── Public API ──────────────────────────────────────────────────────────────

"""Install the litellm monkeypatch (idempotent)."""
def install() {
    global _orig_completion, _orig_acompletion, _installed;
    if _installed {
        return;
    }
    _orig_completion = litellm.completion;
    _orig_acompletion = litellm.acompletion;
    litellm.completion = _make_sync_patch(_orig_completion);
    litellm.acompletion = _make_async_patch(_orig_acompletion);
    _installed = True;
}


"""Restore the original litellm.completion / acompletion."""
def uninstall() {
    global _installed;
    if not _installed {
        return;
    }
    litellm.completion = _orig_completion;
    litellm.acompletion = _orig_acompletion;
    _installed = False;
}


"""Empty the captured-calls log."""
def clear() {
    _log.clear();
}


"""Return a shallow copy of the captured-calls log."""
def get_log() -> list[dict[str, any]] {
    return list(_log);
}


"""Toggle real-time stderr printing of each captured call."""
def set_verbose(flag: bool) {
    global _verbose;
    _verbose = bool(flag);
}


"""True if the patch is currently active."""
def is_installed() -> bool {
    return _installed;
}
