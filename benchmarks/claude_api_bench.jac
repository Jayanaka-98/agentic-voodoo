"""Benchmark: claude-api skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { execute_python, bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/claude-api/SKILL.md").read();

glob TASK: str = """Build a Python customer support agent using the Claude API.

Requirements:
- Script: support_agent.py
- Takes a customer support ticket (subject + body) as input
- Uses prompt caching for the system prompt (support guidelines, ~500 words) to reduce cost
- Classifies ticket urgency (low/medium/high) using structured output
- Generates a professional response using claude-sonnet-4-6
- Logs token usage and cache hit rate to stdout
- Handles API errors gracefully with retry logic (3 attempts, exponential backoff)
- Include a test that runs the agent with a sample ticket about a billing issue
- Save as support_agent.py and show example output""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[execute_python, bash, write_file, read_file],
    max_react_iterations=25
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Write, test, and verify the code artifact.";
sem run_task.skill_text = "Complete skill instructions defining the Claude API, SDK usage patterns, and best practices.";
sem run_task.user_task = "The specific application the user wants built, with all technical requirements.";

with entry {
    setup();
    print("=== BENCHMARK: claude-api ===");
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
    _expected: list = ['support_agent.py'];
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

    show_results("claude-api-baseline", success);
    show_context_breakdown();
}