"""Persistent agent registry at ~/.voodoo-bench/registry.toml.

Schema:
    [agents]
    name = "/abs/path/to/agent_dir"

Agents are dirs containing either:
  - voodoo-bench.toml (manifest), or
  - agent.jac with the required symbols (convention)
"""

import os;
import tomllib;
import from pathlib { Path }


glob CONFIG_DIR: Path = Path(os.environ.get("VOODOO_BENCH_HOME", str(Path.home() / ".voodoo-bench")));
glob REGISTRY_PATH: Path = CONFIG_DIR / "registry.toml";
glob MANIFEST_NAME: str = "voodoo-bench.toml";
glob AGENT_FILE: str = "agent.jac";
glob SKILL_FILE: str = "SKILL.md";


def _ensure_dir() -> None {
    CONFIG_DIR.mkdir(parents=True, exist_ok=True);
}

"""True if `p` looks like a voodoo-bench agent directory."""
def _is_agent_dir(p: Path) -> bool {
    return (p / MANIFEST_NAME).exists() or (p / AGENT_FILE).exists();
}

"""Quote a TOML key only if it isn't a bare-key identifier."""
def _quote_key(name: str) -> str {
    if name.replace("_", "").replace("-", "").isalnum() {
        return name;
    }
    return '"' + name.replace('"', '\\"') + '"';
}


"""Load the {name: abs_path} mapping for all registered agents."""
def load() -> dict[str, str] {
    if not REGISTRY_PATH.exists() {
        return {};
    }
    with open(str(REGISTRY_PATH), "rb") as f {
        data = tomllib.load(f);
    }
    return dict(data.get("agents", {}));
}


"""Persist the registry mapping to disk."""
def save(entries: dict[str, str]) -> None {
    _ensure_dir();
    lines: list[str] = ["[agents]"];
    for name in sorted(entries) {
        path = entries[name].replace('"', '\\"');
        lines.append(f'{_quote_key(name)} = "{path}"');
    }
    REGISTRY_PATH.write_text("\n".join(lines) + "\n");
}


"""Register `path` under `name`. Raises ValueError if path is not an agent dir."""
def register(name: str, path: str) -> None {
    p = Path(path).expanduser().resolve();
    if not p.is_dir() {
        raise ValueError(f"Not a directory: {p}");
    }
    if not _is_agent_dir(p) {
        raise ValueError(
            f"{p} does not look like an agent directory "
            + f"(missing {MANIFEST_NAME} and {AGENT_FILE})"
        );
    }
    entries = load();
    entries[name] = str(p);
    save(entries);
}


"""Remove a registered agent. Returns True if it existed."""
def unregister(name: str) -> bool {
    entries = load();
    if name in entries {
        del entries[name];
        save(entries);
        return True;
    }
    return False;
}


"""Resolve a CLI-given identifier to an agent directory.

Order:
  1. If it's a filesystem path that exists, use it directly.
  2. Look it up in the registry.
"""
def resolve(name_or_path: str) -> Path {
    p = Path(name_or_path).expanduser();
    if p.exists() and p.is_dir() {
        return p.resolve();
    }
    entries = load();
    if name_or_path in entries {
        return Path(entries[name_or_path]);
    }
    raise KeyError(
        f"No agent registered as '{name_or_path}' and no such directory exists. "
        + "Run `voodoo-bench list` to see registered agents."
    );
}


"""Walk a directory tree and return every conforming agent dir as (name, path)."""
def discover(start: str) -> list[tuple[str, Path]] {
    root_path = Path(start).expanduser().resolve();
    found: list[tuple[str, Path]] = [];
    for (dirpath, _, _) in os.walk(str(root_path)) {
        d = Path(dirpath);
        if _is_agent_dir(d) {
            found.append((d.name, d));
        }
    }
    return found;
}


"""Read an agent's voodoo-bench.toml manifest, or {} if absent."""
def read_manifest(agent_dir: Path) -> dict[str, any] {
    manifest = agent_dir / MANIFEST_NAME;
    if not manifest.exists() {
        return {};
    }
    with open(str(manifest), "rb") as f {
        return tomllib.load(f);
    }
}
