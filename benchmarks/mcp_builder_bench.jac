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
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected = ['github_mcp/server.py'];
    _min_kb   = 2;
    _missing, _small = [], [];
    for _f in _expected {
        if not os.path.exists(_f) {
            _missing.append(_f);
        } elif os.path.getsize(_f) < _min_kb * 1024 {
            _small.append(f"{_f} ({round(os.path.getsize(_f)/1024,1)} KB < {_min_kb} KB min)");
        }
    }
    if _missing {
        print(f"  VALIDATION FAILED — missing: {_missing}");
        success = False;
    }
    if _small {
        print(f"  VALIDATION FAILED — too small (empty artifact?): {_small}");
        success = False;
    }
    if not _missing and not _small {
        _sizes = {_f: f"{round(os.path.getsize(_f)/1024,1)} KB" for _f in _expected};
        print(f"  VALIDATION PASSED — {_sizes}");
    }

    show_results("mcp-builder-baseline", success);
    show_context_breakdown();
}