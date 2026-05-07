"""Benchmark: mcp-builder skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { execute_python, bash, write_file, read_file, execute_node }

glob SKILL_TEXT: str = open("skills/skills/mcp-builder/SKILL.md").read();

glob TASK: str = """Create a Python MCP server using FastMCP for GitHub repository management.

Requirements:
- Server name: "github-tools"
- Tool 1: get_repo_info(owner: str, repo: str) — returns repo name, description, stars, open issues
- Tool 2: list_open_issues(owner: str, repo: str, limit: int = 10) — returns list of issue titles and numbers
- Tool 3: create_issue(owner: str, repo: str, title: str, body: str) — creates a new issue
- Use the GitHub REST API (api.github.com) with token auth via GITHUB_TOKEN env var
- Include proper error handling for rate limits and auth failures
- Add a README.md explaining how to configure it in Claude Desktop
- Test by running the server and verifying tools are registered
- Save as github_mcp/server.py and github_mcp/README.md""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[execute_python, bash, write_file, read_file],
    max_react_iterations=25
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Build, configure, and verify the MCP server.";
sem run_task.skill_text = "Complete skill instructions for MCP server development, FastMCP patterns, and deployment.";
sem run_task.user_task = "The specific MCP server the user wants built, with all tools and requirements.";

with entry {
    setup();
    print("=== BENCHMARK: mcp-builder ===");
    print(f"Skill size: {len(SKILL_TEXT)} chars");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True,
     result = "";

with entry {
    try {
        result = run_task(SKILL_TEXT, TASK);
        print(str(result)[:800]);
    } except Exception as e {
        print(f"ERROR: {e}");
        success = False;
    }
}

with entry {
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected: list = ['github_mcp/server.py'];
    _min_kb: int    = 2;
    _missing: list  = [];
    _small: list    = [];
    for _f in _expected {
        if not os.path.exists(_f) {
            _missing.append(_f);
        } else {
            _raw: int  = os.path.getsize(_f);
            _sz: float = _raw / 1024.0;
            if _sz < _min_kb {
                _small.append(f"{_f} ({_sz:.1f} KB < {_min_kb} KB min)");
            }
        }
    }
    if _missing {
        print(f"  VALIDATION FAILED - missing: {_missing}");
        success = False;
    }
    if _small {
        print(f"  VALIDATION FAILED - too small: {_small}");
        success = False;
    }
    if not _missing and not _small {
        print(f"  VALIDATION PASSED - {_expected}");
    }

    show_results("mcp-builder-baseline", success);
    show_context_breakdown();
}