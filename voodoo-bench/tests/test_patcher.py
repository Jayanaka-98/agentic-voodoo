"""Tests for voodoo_bench.patcher — capture behaviour without live LLM calls.

We replace litellm.completion before installing the patcher so the patcher
wraps our fake. Each captured entry must include input_messages and output.
"""

from __future__ import annotations

from typing import Any

import litellm

from voodoo_bench import patcher


class _FakeUsage:
    def __init__(self, p: int = 17, c: int = 5) -> None:
        self.prompt_tokens = p
        self.completion_tokens = c
        self.total_tokens = p + c


class _FakeMessage:
    def __init__(self, content: str, tool_calls: Any = None) -> None:
        self.content = content
        self.tool_calls = tool_calls


class _FakeChoice:
    def __init__(self, msg: _FakeMessage) -> None:
        self.message = msg


class _FakeResponse:
    def __init__(self, content: str = "hi", tool_calls: Any = None) -> None:
        self.choices = [_FakeChoice(_FakeMessage(content, tool_calls))]
        self.usage = _FakeUsage()


def _fake_completion(**kwargs: Any) -> _FakeResponse:
    return _FakeResponse(content="hello world")


def test_install_is_idempotent() -> None:
    original = litellm.completion
    litellm.completion = _fake_completion  # type: ignore[assignment]
    try:
        patcher.install()
        wrapped_once = litellm.completion
        patcher.install()  # second call is a no-op
        assert litellm.completion is wrapped_once
        assert patcher.is_installed()
    finally:
        patcher.uninstall()
        litellm.completion = original  # type: ignore[assignment]


def test_uninstall_restores_original() -> None:
    original = litellm.completion
    litellm.completion = _fake_completion  # type: ignore[assignment]
    try:
        patcher.install()
        assert litellm.completion is not _fake_completion
        patcher.uninstall()
        assert litellm.completion is _fake_completion
    finally:
        litellm.completion = original  # type: ignore[assignment]


def test_capture_records_full_io() -> None:
    original = litellm.completion
    litellm.completion = _fake_completion  # type: ignore[assignment]
    try:
        patcher.install()
        msgs = [
            {"role": "system", "content": "you are a helpful assistant"},
            {"role": "user", "content": "say hello"},
        ]
        litellm.completion(model="openai/gpt-4o-mini", messages=msgs)
        litellm.completion(model="openai/gpt-4o-mini", messages=msgs + [{"role": "assistant", "content": "ok"}])
    finally:
        patcher.uninstall()
        litellm.completion = original  # type: ignore[assignment]

    log = patcher.get_log()
    assert len(log) == 2
    e0, e1 = log
    assert e0["call_index"] == 0 and e1["call_index"] == 1
    assert e0["model"] == "openai/gpt-4o-mini"
    assert e0["prompt_tokens"] == 17 and e0["completion_tokens"] == 5
    # Full transcript captured
    assert e0["input_messages"][0]["role"] == "system"
    assert e0["input_messages"][1]["content"] == "say hello"
    assert e0["output"]["content"] == "hello world"
    # Context bucket totals are non-zero and have the expected keys
    bk = e0["breakdown"]
    assert {"system", "mtir", "asst", "tool", "total", "mtir_pct"} <= set(bk)
    assert bk["total"] > 0


def test_clear_resets_log() -> None:
    original = litellm.completion
    litellm.completion = _fake_completion  # type: ignore[assignment]
    try:
        patcher.install()
        litellm.completion(model="openai/gpt-4o-mini", messages=[{"role": "user", "content": "hi"}])
        assert len(patcher.get_log()) == 1
        patcher.clear()
        assert patcher.get_log() == []
    finally:
        patcher.uninstall()
        litellm.completion = original  # type: ignore[assignment]


def test_set_verbose_does_not_crash(capsys: Any) -> None:
    original = litellm.completion
    litellm.completion = _fake_completion  # type: ignore[assignment]
    try:
        patcher.install()
        patcher.set_verbose(True)
        litellm.completion(model="openai/gpt-4o-mini", messages=[{"role": "user", "content": "hi"}])
        patcher.set_verbose(False)
    finally:
        patcher.uninstall()
        litellm.completion = original  # type: ignore[assignment]

    captured = capsys.readouterr()
    assert "LLM call #1" in captured.err
    assert "hello world" in captured.err
