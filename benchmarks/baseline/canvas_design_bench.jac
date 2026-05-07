"""Benchmark: canvas-design skill — end-to-end task baseline measurement."""

import os;
import from ..lib.measure { setup, show_results, show_context_breakdown }
import from ..lib.tools { execute_python, bash, write_file, read_file }

glob _SKILLS_ROOT: str = os.environ.get("SKILLS_ROOT", "skills/anthropic/skills");
glob SKILL_TEXT: str = open(f"{_SKILLS_ROOT}/canvas-design/SKILL.md").read();

glob TASK: str = """Create an original poster design for a fictional music festival called "Neon Equinox".

Festival details: 3-day electronic music festival, September 20-22 2025, at a desert location.
Headliners: Daft Punk (reunion), Aphex Twin, Arca.

Creative brief:
- Express the feeling of technology meeting nature — circuits becoming organic, code becoming light
- NOT a generic festival poster. Must feel like a specific art movement.
- Output a design philosophy manifesto first, then express it visually
- Final deliverable: poster at 2400x3600px (portrait), 300dpi equivalent
- Required text elements: festival name, dates, location, headliner names — but make them part of the art, not afterthoughts
- File format: PDF (for print quality) and PNG (for web)
- Save as neon_equinox/philosophy.md, neon_equinox/poster.pdf, neon_equinox/poster.png""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[execute_python, bash, write_file, read_file],
    max_react_iterations=20
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Create the design philosophy and visual artifacts.";
sem run_task.skill_text = "Complete skill instructions for canvas-based visual design, design philosophy creation, and file output.";
sem run_task.user_task = "The specific poster design the user wants created, with artistic direction and all requirements.";

with entry {
    setup();
    print("=== BENCHMARK: canvas-design ===");
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
    _expected: list = ['neon_equinox/philosophy.md'];
    _min_kb: int    = 1;
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

    show_results("canvas-design-baseline", success);
    show_context_breakdown();
}