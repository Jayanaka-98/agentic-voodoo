"""End-to-end run-path test using byllm's MockLLM.

MockLLM (Model(model_name="mockllm", outputs=[...])) returns scripted values
without touching the network or litellm — exactly what we need to verify the
CLI → loader → agent → byllm pipeline without a real model behind it.

Note: MockLLM bypasses litellm.completion, so patcher.get_log() will be empty
after these runs. That's expected and intentional — the patcher unit tests
in test_patcher.py cover the litellm interception layer separately.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from voodoo_bench import cli, registry


def _write_byllm_agent(d: Path) -> None:
    """Write an agent.jac whose `run` actually goes through `by llm(...)`.

    The agent's by-llm function returns a str, which MockLLM scripts via
    `outputs=[...]`. The loader will call `run(task, llm, skill)` with the
    Model instance the CLI constructs from --model.
    """
    (d / "agent.jac").write_text(
        '"""MockLLM-driven test agent."""\n'
        '\n'
        'import from byllm.lib { Model }\n'
        '\n'
        'glob DEFAULT_TASK: str = "say something";\n'
        '\n'
        'def _summarise(skill_text: str, user_task: str, llm: Model) -> str by llm(model=llm);\n'
        '\n'
        'def run(task: str, llm: Model, skill: str) -> str {\n'
        '    return _summarise(skill, task, llm);\n'
        '}\n'
    )


def test_run_with_mockllm_invokes_agent(
    isolated_home: Path,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    # Build a conforming agent dir.
    agent_dir = tmp_path / "mock_agent"
    agent_dir.mkdir()
    _write_byllm_agent(agent_dir)
    (agent_dir / "voodoo-bench.toml").write_text(
        'name = "mock_agent"\ndefault_task = "what is 2+2?"\n'
    )
    (agent_dir / "SKILL.md").write_text("Just answer concisely.\n")

    # Send results to a tmp dir.
    results_dir = tmp_path / "results"

    # Pre-build a MockLLM-backed model and inject it into model_factory so the
    # CLI uses it instead of constructing a real provider connection. The
    # `outputs=[...]` list scripts what byllm hands back.
    from byllm.lib import Model
    scripted_response = "the answer is four"
    mock_model = Model(model_name="mockllm", config={"outputs": [scripted_response]})

    # `cli.jac` did `import from voodoo_bench.model_factory { build_model }`,
    # which binds the symbol into cli's namespace at import time. Patch the
    # bound name there, not in model_factory itself.
    from voodoo_bench import cli
    monkeypatch.setattr(cli, "build_model", lambda **kw: mock_model)

    rc = cli.main([
        "run",
        str(agent_dir),
        "--model", "mockllm",
        "--results-dir", str(results_dir),
    ])

    out = capsys.readouterr().out
    assert rc == 0, f"CLI exited non-zero. stdout: {out}"
    # Agent's return value should appear in the CLI's output.
    assert scripted_response in out
    # Run summary artifacts written.
    assert (results_dir / "mock_agent_results.json").exists()
    assert (results_dir / "mock_agent_runs.jsonl").exists()


def test_resolve_uses_registered_alias_at_run_time(
    isolated_home: Path,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Registered aliases resolve to the on-disk agent during `run`."""
    agent_dir = tmp_path / "alias_agent"
    agent_dir.mkdir()
    _write_byllm_agent(agent_dir)
    (agent_dir / "voodoo-bench.toml").write_text('name = "alias_agent"\n')
    (agent_dir / "SKILL.md").write_text("be terse.\n")

    registry.register("aliased", str(agent_dir))

    from byllm.lib import Model
    mock_model = Model(model_name="mockllm", config={"outputs": ["aliased ok"]})
    # `cli.jac` did `import from voodoo_bench.model_factory { build_model }`,
    # which binds the symbol into cli's namespace at import time. Patch the
    # bound name there, not in model_factory itself.
    from voodoo_bench import cli
    monkeypatch.setattr(cli, "build_model", lambda **kw: mock_model)

    rc = cli.main([
        "run", "aliased",
        "--model", "mockllm",
        "--results-dir", str(tmp_path / "out"),
    ])
    out = capsys.readouterr().out
    assert rc == 0
    assert "aliased ok" in out
