"""voodoo-bench CLI — argparse + dispatch + agent loader.

Subcommands:
  run        Execute an agent with a model and task
  list       List registered agents
  register   Register an agent directory under a name
  unregister Remove a registered agent
  discover   Walk a directory tree and register every conforming agent

The litellm patcher is installed in `cmd_run` before any agent code loads.
"""

import os;
import sys;
import argparse;
import importlib;
import importlib.util;
import traceback;
import from pathlib { Path }

import from voodoo_bench { patcher, registry, measure }
import from voodoo_bench.model_factory { build_model }


glob VERSION: str = "0.1.0";


# ── Agent loading ────────────────────────────────────────────────────────────

"""jac-import agent.jac from `agent_dir` and return the resulting module."""
def _load_agent_module(agent_dir: Path) -> any {
    agent_dir = agent_dir.resolve();
    agent_file = agent_dir / registry.AGENT_FILE;
    if not agent_file.exists() {
        raise FileNotFoundError(f"No {registry.AGENT_FILE} in {agent_dir}");
    }
    parent = str(agent_dir.parent);
    if parent not in sys.path {
        sys.path.insert(0, parent);
    }
    mod_name = agent_dir.name.replace("-", "_");

    # Fast path: load via the jaclang meta-importer.
    try {
        mod = importlib.import_module(mod_name + ".agent");
        if mod is not None {
            return mod;
        }
    } except Exception {}

    # Fallback: load the .jac via spec_from_file_location.
    spec_name = f"{mod_name}_agent_jac";
    spec = importlib.util.spec_from_file_location(spec_name, str(agent_file));
    if spec is None or spec.loader is None {
        raise ImportError(f"Could not load {agent_file}");
    }
    module = importlib.util.module_from_spec(spec);
    sys.modules[spec_name] = module;
    spec.loader.exec_module(module);
    return module;
}


"""Resolve the skill text for this run from CLI override / manifest / SKILL.md."""
def _resolve_skill(agent_dir: Path, manifest: dict[str, any], skill_path: str) -> str {
    if skill_path {
        return Path(skill_path).expanduser().read_text();
    }
    default = manifest.get("default_skill");
    if default {
        p = (agent_dir / default).resolve();
        if p.exists() {
            return p.read_text();
        }
    }
    fallback = agent_dir / registry.SKILL_FILE;
    if fallback.exists() {
        return fallback.read_text();
    }
    return "";
}


"""Resolve the task string from CLI override / file / manifest / agent default."""
def _resolve_task(manifest: dict[str, any], mod: any, task_text: str, task_file: str) -> str {
    if task_file {
        return Path(task_file).expanduser().read_text();
    }
    if task_text {
        return task_text;
    }
    if "default_task" in manifest {
        return str(manifest["default_task"]);
    }
    if hasattr(mod, "DEFAULT_TASK") {
        return str(getattr(mod, "DEFAULT_TASK"));
    }
    raise ValueError(
        "No task provided. Pass --task / --task-file, or define DEFAULT_TASK "
        + "in the agent or default_task in voodoo-bench.toml."
    );
}


# ── Subcommands ──────────────────────────────────────────────────────────────

def cmd_run(args: any) -> int {
    agent_dir = registry.resolve(args.agent);
    manifest = registry.read_manifest(agent_dir);

    label = args.label or manifest.get("name") or agent_dir.name;
    if args.results_dir {
        os.environ["RESULTS_DIR"] = args.results_dir;
    }
    patcher.set_verbose(args.verbose);

    print(f"=== voodoo-bench: {label} ===");
    print(f"  agent:    {agent_dir}");
    print(f"  model:    {args.model}");
    if args.base_url {
        print(f"  base_url: {args.base_url}");
    }

    llm = build_model(
        spec=args.model,
        base_url=args.base_url or "",
        api_key=args.api_key or "",
        extra=args.model_arg or []
    );

    mod = _load_agent_module(agent_dir);
    if not hasattr(mod, "run") {
        print(f"ERROR: agent {agent_dir} has no `run` function", file=sys.stderr);
        return 2;
    }

    skill = _resolve_skill(agent_dir, manifest, args.skill or "");
    task  = _resolve_task(manifest, mod, args.task or "", args.task_file or "");

    print(f"  skill:    {len(skill)} chars");
    print(f"  task:     {task[:120]}{'...' if len(task) > 120 else ''}");
    print("");

    measure.setup(label);
    success: bool = True;
    try {
        result = mod.run(task, llm, skill);
        if result is not None {
            print(str(result)[:1200]);
        }
    } except Exception as e {
        success = False;
        print(f"\nERROR: {e}\n", file=sys.stderr);
        traceback.print_exc();
    } finally {
        measure.show_results(label=label, success=success);
        if args.context_breakdown {
            measure.show_context_breakdown();
        }
        measure.teardown();
    }
    return 0 if success else 1;
}


def cmd_list(args: any) -> int {
    entries = registry.load();
    if not entries {
        print("(no agents registered — try `voodoo-bench register <name> <path>`)");
        return 0;
    }
    width = max([len(n) for n in entries]);
    for name in sorted(entries) {
        print(f"  {name:<{width}}  {entries[name]}");
    }
    return 0;
}


def cmd_register(args: any) -> int {
    registry.register(args.name, args.path);
    print(f"Registered '{args.name}' -> {Path(args.path).resolve()}");
    return 0;
}


def cmd_unregister(args: any) -> int {
    if registry.unregister(args.name) {
        print(f"Removed '{args.name}'");
        return 0;
    }
    print(f"No agent registered as '{args.name}'", file=sys.stderr);
    return 1;
}


def cmd_discover(args: any) -> int {
    found = registry.discover(args.path);
    if not found {
        print(f"No agents found under {args.path}");
        return 0;
    }
    if args.dry_run {
        for (name, path) in found {
            print(f"  {name:<24}  {path}");
        }
        print(f"\n({len(found)} found — re-run without --dry-run to register them)");
        return 0;
    }
    entries = registry.load();
    for (name, path) in found {
        entries[name] = str(path);
    }
    registry.save(entries);
    for (name, path) in found {
        print(f"  registered {name:<24}  {path}");
    }
    return 0;
}


# ── argparse wiring ──────────────────────────────────────────────────────────

def _build_parser() -> argparse.ArgumentParser {
    p = argparse.ArgumentParser(
        prog="voodoo-bench",
        description="Run any Jac/byLLM agent with a chosen model and capture every prompt/completion."
    );
    p.add_argument("--version", action="version", version=f"voodoo-bench {VERSION}");
    sub = p.add_subparsers(dest="cmd", required=True);

    pr = sub.add_parser("run", help="Run an agent");
    pr.add_argument("agent", help="Registered name or absolute path to an agent dir");
    pr.add_argument("--model", required=True, help="Model spec, e.g. anthropic/claude-opus-4-7, openai/gpt-4o, vllm:Qwen/Qwen2.5-72B");
    pr.add_argument("--base-url", help="Base URL for OpenAI-compatible / vLLM servers");
    pr.add_argument("--api-key", help="API key override");
    pr.add_argument("--model-arg", action="append", default=[], help="Extra model kwarg, e.g. --model-arg temperature=0.0 (repeatable)");
    pr.add_argument("--task", help="Task string");
    pr.add_argument("--task-file", help="Path to a file containing the task");
    pr.add_argument("--skill", help="Path to skill file (overrides agent default)");
    pr.add_argument("--label", help="Label for results files (defaults to agent name)");
    pr.add_argument("--results-dir", help="Where to write *_runs.jsonl and *_results.json");
    pr.add_argument("--verbose", "-v", action="store_true", help="Print every LLM input/output to stderr as calls return");
    pr.add_argument("--context-breakdown", action="store_true", help="Print per-call context-bucket breakdown after the run");
    pr.set_defaults(func=cmd_run);

    pl = sub.add_parser("list", help="List registered agents");
    pl.set_defaults(func=cmd_list);

    pg = sub.add_parser("register", help="Register an agent dir under a name");
    pg.add_argument("name");
    pg.add_argument("path");
    pg.set_defaults(func=cmd_register);

    pu = sub.add_parser("unregister", help="Remove a registered agent");
    pu.add_argument("name");
    pu.set_defaults(func=cmd_unregister);

    pd = sub.add_parser("discover", help="Walk a directory tree and register every conforming agent");
    pd.add_argument("path");
    pd.add_argument("--dry-run", action="store_true", help="List what would be registered without modifying the registry");
    pd.set_defaults(func=cmd_discover);

    return p;
}


"""voodoo-bench main — invoked by the [project.scripts] shim."""
def main(argv: list[str] | None = None) -> int {
    parser = _build_parser();
    args = parser.parse_args(argv);
    return int(args.func(args) or 0);
}


with entry {
    if __name__ == "__main__" {
        raise SystemExit(main());
    }
}
