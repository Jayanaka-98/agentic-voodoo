"""Shared fixtures for the voodoo-bench test suite.

Every test runs against an isolated VOODOO_BENCH_HOME so the developer's
real registry at ~/.voodoo-bench/ is never touched.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest


@pytest.fixture
def isolated_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Point VOODOO_BENCH_HOME at a tmp dir and reset registry's cached globals."""
    home = tmp_path / "vbench-home"
    home.mkdir()
    monkeypatch.setenv("VOODOO_BENCH_HOME", str(home))

    # registry.jac caches CONFIG_DIR / REGISTRY_PATH at module load. Rebind them
    # to the new env so each test sees its own filesystem.
    from voodoo_bench import registry
    registry.CONFIG_DIR = home
    registry.REGISTRY_PATH = home / "registry.toml"
    return home


@pytest.fixture
def sample_agent(tmp_path: Path) -> Path:
    """Create a minimal conforming agent directory and return its path."""
    d = tmp_path / "sample_agent"
    d.mkdir()
    (d / "voodoo-bench.toml").write_text(
        'name = "sample"\n'
        'default_task = "say hello"\n'
        'default_skill = "SKILL.md"\n'
    )
    (d / "SKILL.md").write_text("# Sample Skill\n\nJust say hello.\n")
    (d / "agent.jac").write_text(
        '"""Tiny test agent."""\n'
        '\n'
        'glob DEFAULT_TASK: str = "say hello";\n'
        '\n'
        'def run(task: str, llm: any, skill: str) -> str {\n'
        '    return f"got task={task!r} skill_len={len(skill)}";\n'
        '}\n'
    )
    return d


@pytest.fixture(autouse=True)
def reset_patcher_state() -> None:
    """Make sure the patcher is uninstalled and the log is clean between tests."""
    from voodoo_bench import patcher
    if patcher.is_installed():
        patcher.uninstall()
    patcher.clear()
    yield
    if patcher.is_installed():
        patcher.uninstall()
    patcher.clear()
