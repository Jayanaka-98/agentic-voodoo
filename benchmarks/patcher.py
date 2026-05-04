"""
Monkeypatch litellm.completion/acompletion to capture every LLM call,
including every ReAct iteration inside a byLLM agent loop.

Usage from Jac:
    import patcher;
    glob _patcher: Any = patcher;
    _patcher.install();          # in setup
    calls = _patcher.get_log()  # after run
    _patcher.clear()
"""

import json
import time
import litellm
import tiktoken

_log: list[dict] = []
_orig_completion = None
_orig_acompletion = None
_installed = False


# ── Tiktoken helpers ──────────────────────────────────────────────────────────

def _enc(model: str):
    try:
        return tiktoken.encoding_for_model(model)
    except Exception:
        return tiktoken.get_encoding("cl100k_base")


def _serialize(obj) -> str:
    """Serialize to JSON, falling back gracefully for Pydantic objects."""
    try:
        return json.dumps(obj)
    except (TypeError, ValueError):
        pass
    if isinstance(obj, list):
        parts = []
        for item in obj:
            if hasattr(item, "model_dump"):
                parts.append(item.model_dump())
            elif hasattr(item, "__dict__"):
                parts.append(vars(item))
            else:
                parts.append(str(item))
        try:
            return json.dumps(parts)
        except Exception:
            pass
    return str(obj)


def _count_message(msg: dict, enc) -> int:
    """Token count for one message including 4-token framing overhead."""
    total = 4
    content = msg.get("content", "") or ""
    if isinstance(content, list):
        for block in content:
            if isinstance(block, dict):
                text = str(
                    block.get("text") or block.get("content") or ""
                )
            else:
                text = str(block)
            total += len(enc.encode(text))
    else:
        total += len(enc.encode(str(content)))
    tool_calls = msg.get("tool_calls")
    if tool_calls:
        total += len(enc.encode(_serialize(tool_calls)))
    return total


def _categorize(messages: list, enc) -> dict:
    system_t = 0
    mtir_t = 0
    asst_t = 0
    tool_t = 0
    for i, msg in enumerate(messages):
        t = _count_message(msg, enc)
        role = msg.get("role", "")
        if i == 0:
            system_t += t
        elif i == 1:
            mtir_t += t
        elif role == "assistant":
            asst_t += t
        elif role in ("tool", "function"):
            tool_t += t
        else:
            mtir_t += t
    total = system_t + mtir_t + asst_t + tool_t
    return {
        "system": system_t,
        "mtir": mtir_t,
        "asst": asst_t,
        "tool": tool_t,
        "total": total,
        "mtir_pct": round(mtir_t / total * 100, 1) if total else 0,
    }


def _record(kwargs, response, duration_ms):
    """Append one entry to the call log."""
    messages = list(kwargs.get("messages") or [])
    model = str(kwargs.get("model") or "unknown")
    enc = _enc(model)
    breakdown = _categorize(messages, enc)
    usage = getattr(response, "usage", None)
    _log.append({
        "call_index": len(_log),
        "model": model,
        "message_count": len(messages),
        "breakdown": breakdown,
        "prompt_tokens": int(
            getattr(usage, "prompt_tokens", 0) or 0
        ),
        "completion_tokens": int(
            getattr(usage, "completion_tokens", 0) or 0
        ),
        "total_tokens": int(
            getattr(usage, "total_tokens", 0) or 0
        ),
        "duration_ms": round(duration_ms, 1),
    })


# ── Patch factory ─────────────────────────────────────────────────────────────

def _make_sync_patch(original):
    def patched(*args, **kwargs):
        t0 = time.time()
        response = original(*args, **kwargs)
        _record(kwargs, response, (time.time() - t0) * 1000.0)
        return response
    return patched


def _make_async_patch(original):
    async def patched(*args, **kwargs):
        t0 = time.time()
        response = await original(*args, **kwargs)
        _record(kwargs, response, (time.time() - t0) * 1000.0)
        return response
    return patched


# ── Public API ────────────────────────────────────────────────────────────────

def install() -> None:
    global _orig_completion, _orig_acompletion, _installed
    if _installed:
        return
    _orig_completion = litellm.completion
    _orig_acompletion = litellm.acompletion
    litellm.completion = _make_sync_patch(_orig_completion)
    litellm.acompletion = _make_async_patch(_orig_acompletion)
    _installed = True


def uninstall() -> None:
    global _installed
    if not _installed:
        return
    litellm.completion = _orig_completion
    litellm.acompletion = _orig_acompletion
    _installed = False


def clear() -> None:
    _log.clear()


def get_log() -> list:
    return list(_log)
