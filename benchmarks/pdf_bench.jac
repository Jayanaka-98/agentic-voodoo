"""Benchmark: pdf skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { execute_python, bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/pdf/SKILL.md").read();

glob TASK: str = """Create a 3-page PDF report on Q1 2024 sales performance.

Requirements:
- Cover page with title, date, and company name "Acme Corp"
- Summary table showing monthly revenue: Jan $120k, Feb $145k, Mar $162k
- Key metrics section: total revenue $427k, 35% YoY growth, top product "Widget Pro"
- Professional styling with a header on each page
- Save as q1_sales_report.pdf""";

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
    print("=== BENCHMARK: pdf ===");
    print(f"Skill size: {len(SKILL_TEXT)} chars");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True,
     result = "";

with entry {
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected: list = ['q1_sales_report.pdf'];
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

    show_results("pdf-baseline", success);
    show_context_breakdown();
}