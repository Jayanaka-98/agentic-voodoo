"""Tests for voodoo_bench.model_factory — spec parsing + Model construction."""

from __future__ import annotations

import pytest

from voodoo_bench import model_factory


def test_provider_spec_passes_through() -> None:
    m = model_factory.build_model("openai/gpt-4o")
    assert getattr(m, "model_name", None) == "openai/gpt-4o"


def test_anthropic_spec_passes_through() -> None:
    m = model_factory.build_model("anthropic/claude-opus-4-7")
    assert getattr(m, "model_name", None) == "anthropic/claude-opus-4-7"


def test_vllm_prefix_rewrites_to_hosted_vllm() -> None:
    m = model_factory.build_model(
        "vllm:Qwen/Qwen2.5-72B-Instruct",
        base_url="http://localhost:8000/v1",
    )
    assert getattr(m, "model_name", None) == "hosted_vllm/Qwen/Qwen2.5-72B-Instruct"


def test_vllm_without_base_url_raises() -> None:
    with pytest.raises(ValueError, match="--base-url is required"):
        model_factory.build_model("vllm:Qwen/Qwen2.5-72B-Instruct")


def test_extra_model_args_are_coerced() -> None:
    # Just check parsing doesn't crash and the kwargs land somewhere on the
    # model object. byllm.Model stores call params; we don't assert on internals
    # beyond construction succeeding.
    m = model_factory.build_model(
        "openai/gpt-4o-mini",
        extra=["temperature=0.0", "max_tokens=128", "stream=false"],
    )
    assert m is not None


def test_invalid_model_arg_format_raises() -> None:
    with pytest.raises(ValueError, match="must be key=value"):
        model_factory.build_model("openai/gpt-4o", extra=["bogus"])
