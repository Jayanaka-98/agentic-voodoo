"""Benchmark: docx skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { execute_python, bash, write_file, read_file, execute_node }

glob SKILL_TEXT: str = open("skills/skills/docx/SKILL.md").read();

glob TASK: str = """Create a professional software project proposal document for a mobile banking app.

Requirements:
- Title page: "Mobile Banking Platform — Project Proposal", client "FinBank Ltd", date April 2024
- Table of contents (auto-generated)
- Section 1 Executive Summary: 2 paragraphs on project scope and value
- Section 2 Technical Approach: architecture overview, tech stack (React Native, Node.js, PostgreSQL)
- Section 3 Timeline: 4-phase table (Discovery 2w, Design 4w, Development 16w, Testing 4w)
- Section 4 Budget: itemized table totaling $340,000
- Section 5 Team: 3 roles with names and bios (placeholder text)
- Header with company logo placeholder, footer with page numbers
- Professional styling, Calibri font, navy accent color #1E3A5F
- Save as mobile_banking_proposal.docx""";

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
    print("=== BENCHMARK: docx ===");
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
    _expected: list = ['mobile_banking_proposal.docx'];
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

    show_results("docx-baseline", success);
    show_context_breakdown();
}