"""Tests for voodoo_bench.measure — JSONL/JSON dump and totals."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import litellm
import pytest

from voodoo_bench import measure, patcher


class _FakeUsage:
    def __init__(self) -> None:
        self.prompt_tokens = 11
        self.completion_tokens = 7
        self.total_tokens = 18


class _FakeResp:
    def __init__(self) -> None:
        class _M:
            content = "ok"
            tool_calls = None
        class _C:
            message = _M()
        self.choices = [_C()]
        self.usage = _FakeUsage()


def _fake(**kwargs: Any) -> _FakeResp:
    return _FakeResp()


def test_setup_show_results_writes_artifacts(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("RESULTS_DIR", str(tmp_path))
    original = litellm.completion
    litellm.completion = _fake  # type: ignore[assignment]
    try:
        measure.setup("test_run")
        # Two captured calls.
        litellm.completion(model="x", messages=[{"role": "user", "content": "a"}])
        litellm.completion(model="x", messages=[{"role": "user", "content": "b"}])
        result = measure.show_results(label="test_run", success=True)
    finally:
        measure.teardown()
        litellm.completion = original  # type: ignore[assignment]

    assert result["llm_api_calls"] == 2
    assert result["prompt_tokens"] == 22
    assert result["completion_tokens"] == 14
    assert result["total_tokens"] == 36

    runs_path = tmp_path / "test_run_runs.jsonl"
    summary_path = tmp_path / "test_run_results.json"
    assert runs_path.exists() and summary_path.exists()

    # Re-parse the JSONL row and confirm full transcripts are inside it.
    [row] = [json.loads(line) for line in runs_path.read_text().splitlines() if line]
    assert row["llm_api_calls"] == 2
    assert row["per_api_call"][0]["input_messages"][0]["content"] == "a"
    assert row["per_api_call"][1]["output"]["content"] == "ok"


def test_show_results_handles_zero_calls(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("RESULTS_DIR", str(tmp_path))
    measure.setup("empty_run")
    try:
        result = measure.show_results(label="empty_run", success=False)
    finally:
        measure.teardown()
    assert result["llm_api_calls"] == 0
    assert result["success"] is False
