"""Benchmark: pptx skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { execute_python, bash, write_file, read_file, execute_node }

glob SKILL_TEXT: str = open("skills/skills/pptx/SKILL.md").read();

glob TASK: str = """Create a 5-slide investor pitch deck for a climate tech startup called "GreenFlow".

Requirements:
- Slide 1: Title slide — company name, tagline "Turning carbon into opportunity", dark navy background
- Slide 2: Problem — current carbon tracking is expensive and inaccurate (3 bullet points)
- Slide 3: Solution — AI-powered carbon measurement platform (diagram description + 3 benefits)
- Slide 4: Traction — 12 enterprise pilots, $2.4M ARR, 3 Fortune 500 customers
- Slide 5: Ask — raising $8M Series A, use of funds breakdown
- Color palette: navy (#0A1628), emerald (#10B981), white. Bold typography, minimal bullets.
- Save as greenflow_pitch.pptx""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[execute_python, bash, write_file, read_file, execute_node],
    max_react_iterations=30
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Use tools iteratively until the artifact is fully created and saved.";
sem run_task.skill_text = "Complete skill instructions defining tools, workflow, and best practices for this task type.";
sem run_task.user_task = "The specific artifact the user wants created, with all requirements.";

with entry {
    setup();
    print("=== BENCHMARK: pptx ===");
    print(f"Skill size: {len(SKILL_TEXT)} chars");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True,
     result = "";

with entry {
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected = ['greenflow_pitch.pptx'];
    _min_kb   = 50;
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

    show_results("pptx-baseline", success);
    show_context_breakdown();
}