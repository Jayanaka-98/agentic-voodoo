"""Benchmark: xlsx skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { execute_python, bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/xlsx/SKILL.md").read();

glob TASK: str = """Build a 3-year financial model spreadsheet for a SaaS startup.

Requirements:
- Sheet 1 "Assumptions": ARR growth rate (80%, 60%, 45%), gross margin (72%), headcount growth
- Sheet 2 "P&L": Monthly revenue, COGS, gross profit, OpEx, EBITDA for 2024-2026
- Sheet 3 "Summary": Annual totals with YoY growth %, a chart of ARR progression
- Color coding: input cells in light blue, formula cells in white, negative values in red
- Formulas must reference Assumptions sheet (no hardcoded numbers in P&L)
- Starting ARR: $1.2M in Jan 2024
- Save as saas_financial_model.xlsx""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[execute_python, bash, write_file, read_file],
    max_react_iterations=30
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Use tools iteratively until the artifact is fully created and saved.";
sem run_task.skill_text = "Complete skill instructions defining tools, workflow, and best practices for this task type.";
sem run_task.user_task = "The specific artifact the user wants created, with all requirements.";

with entry {
    setup();
    print("=== BENCHMARK: xlsx ===");
    print(f"Skill size: {len(SKILL_TEXT)} chars");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True,
     result = "";

with entry {
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected: list = ['saas_financial_model.xlsx'];
    _min_kb: int    = 10;
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

    show_results("xlsx-baseline", success);
    show_context_breakdown();
}