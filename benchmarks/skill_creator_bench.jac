"""Benchmark: skill-creator skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/skill-creator/SKILL.md").read();

glob TASK: str = """Create a new Claude Code skill for data analysis workflows.

Skill name: data-analyst
Target use case: When users want to analyze CSV/Excel datasets, generate statistics,
create visualizations, or build data pipelines.

The skill should cover:
- Trigger conditions: when user mentions CSV, Excel, DataFrame, data analysis, statistics, plot, chart, histogram
- Core workflow: load data → explore/profile → clean → analyze → visualize → summarize
- Tool usage: Python with pandas, matplotlib/seaborn, scipy.stats
- Key capabilities:
  1. Data profiling (shape, dtypes, missing values, basic stats)
  2. Cleaning (handle nulls, outliers, type coercion)
  3. Statistical analysis (correlation, distribution, hypothesis tests)
  4. Visualization (save charts as PNG files)
  5. Summary report generation
- Best practices section: always sample large files first, explain statistical choices, save outputs
- Anti-patterns: never modify original data in place, never assume column names
- Include 3 worked examples as reference

Output the complete SKILL.md file following the standard skill format.
Save as data_analyst/SKILL.md""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[bash, write_file, read_file],
    max_react_iterations=20
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Create and save the complete skill definition.";
sem run_task.skill_text = "Complete skill instructions for skill creation, SKILL.md format, and content guidelines.";
sem run_task.user_task = "The specific new skill the user wants created, with all capability and format requirements.";

with entry {
    setup();
    print("=== BENCHMARK: skill-creator ===");
    print(f"Skill size: {len(SKILL_TEXT)} chars");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True,
     result = "";

with entry {
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected = ['data_analyst/SKILL.md'];
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

    show_results("skill-creator-baseline", success);
    show_context_breakdown();
}