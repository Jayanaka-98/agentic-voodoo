"""Tests for voodoo_bench.cli — argparse dispatch and registry-side subcommands.

We don't exercise `run` end-to-end here (that requires a live LLM); the
patcher + measure tests cover that behavior. These tests focus on the CLI
command surface and parser wiring.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from voodoo_bench import cli


def test_list_when_empty_prints_hint(isolated_home: Path, capsys: pytest.CaptureFixture[str]) -> None:
    rc = cli.main(["list"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "no agents registered" in out


def test_register_then_list(isolated_home: Path, sample_agent: Path, capsys: pytest.CaptureFixture[str]) -> None:
    rc = cli.main(["register", "myagent", str(sample_agent)])
    assert rc == 0
    capsys.readouterr()  # drain
    rc = cli.main(["list"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "myagent" in out
    assert str(sample_agent) in out


def test_unregister(isolated_home: Path, sample_agent: Path, capsys: pytest.CaptureFixture[str]) -> None:
    cli.main(["register", "tmp", str(sample_agent)])
    capsys.readouterr()
    rc = cli.main(["unregister", "tmp"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "Removed 'tmp'" in out


def test_unregister_unknown_returns_1(isolated_home: Path, capsys: pytest.CaptureFixture[str]) -> None:
    rc = cli.main(["unregister", "ghost"])
    err = capsys.readouterr().err
    assert rc == 1
    assert "No agent registered" in err


def test_discover_dry_run(isolated_home: Path, tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    base = tmp_path / "agents_root"
    for name in ("alpha", "beta"):
        d = base / name
        d.mkdir(parents=True)
        (d / "agent.jac").write_text("def run(t: str, m: any, s: str) -> str { return t; }\n")
    rc = cli.main(["discover", str(base), "--dry-run"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "alpha" in out and "beta" in out
    # --dry-run must NOT actually register
    from voodoo_bench import registry
    assert registry.load() == {}


def test_discover_registers(isolated_home: Path, tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    base = tmp_path / "agents_root"
    for name in ("alpha", "beta"):
        d = base / name
        d.mkdir(parents=True)
        (d / "agent.jac").write_text("def run(t: str, m: any, s: str) -> str { return t; }\n")
    rc = cli.main(["discover", str(base)])
    assert rc == 0
    from voodoo_bench import registry
    entries = registry.load()
    assert sorted(entries) == ["alpha", "beta"]


def test_run_requires_model(isolated_home: Path, sample_agent: Path) -> None:
    with pytest.raises(SystemExit):
        cli.main(["run", str(sample_agent)])  # --model is required
