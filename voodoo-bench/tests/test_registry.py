"""Tests for voodoo_bench.registry — TOML round-trip, register/discover/resolve."""

from __future__ import annotations

from pathlib import Path

import pytest

from voodoo_bench import registry


def test_load_returns_empty_when_no_registry(isolated_home: Path) -> None:
    assert registry.load() == {}


def test_register_and_load_round_trip(isolated_home: Path, sample_agent: Path) -> None:
    registry.register("a1", str(sample_agent))
    assert registry.load() == {"a1": str(sample_agent)}
    assert registry.REGISTRY_PATH.exists()


def test_register_rejects_non_directory(isolated_home: Path, tmp_path: Path) -> None:
    f = tmp_path / "not_a_dir.txt"
    f.write_text("hi")
    with pytest.raises(ValueError, match="Not a directory"):
        registry.register("x", str(f))


def test_register_rejects_non_agent_dir(isolated_home: Path, tmp_path: Path) -> None:
    d = tmp_path / "bare"
    d.mkdir()
    with pytest.raises(ValueError, match="does not look like an agent directory"):
        registry.register("x", str(d))


def test_unregister_removes_entry(isolated_home: Path, sample_agent: Path) -> None:
    registry.register("a1", str(sample_agent))
    assert registry.unregister("a1") is True
    assert registry.load() == {}


def test_unregister_returns_false_for_unknown(isolated_home: Path) -> None:
    assert registry.unregister("ghost") is False


def test_resolve_by_path(isolated_home: Path, sample_agent: Path) -> None:
    resolved = registry.resolve(str(sample_agent))
    assert Path(str(resolved)).resolve() == sample_agent.resolve()


def test_resolve_by_registered_name(isolated_home: Path, sample_agent: Path) -> None:
    registry.register("a1", str(sample_agent))
    resolved = registry.resolve("a1")
    assert Path(str(resolved)) == sample_agent.resolve()


def test_resolve_unknown_raises(isolated_home: Path) -> None:
    with pytest.raises(KeyError, match="No agent registered"):
        registry.resolve("does-not-exist")


def test_discover_finds_nested_agents(isolated_home: Path, tmp_path: Path) -> None:
    base = tmp_path / "agents"
    for name in ("alpha", "beta"):
        d = base / name
        d.mkdir(parents=True)
        (d / "agent.jac").write_text("def run(t: str, m: any, s: str) -> str { return t; }\n")
    found = registry.discover(str(base))
    names = sorted([n for (n, _) in found])
    assert names == ["alpha", "beta"]


def test_read_manifest(isolated_home: Path, sample_agent: Path) -> None:
    m = registry.read_manifest(sample_agent)
    assert m["name"] == "sample"
    assert m["default_task"] == "say hello"


def test_read_manifest_missing_returns_empty(tmp_path: Path) -> None:
    d = tmp_path / "no_manifest"
    d.mkdir()
    (d / "agent.jac").write_text("\n")
    assert registry.read_manifest(d) == {}
