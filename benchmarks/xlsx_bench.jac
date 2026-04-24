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
    _expected = ['saas_financial_model.xlsx'];
    _min_kb   = 10;
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

    show_results("xlsx-baseline", success);
    show_context_breakdown();
}