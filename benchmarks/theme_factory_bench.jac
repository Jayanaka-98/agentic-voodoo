"""Benchmark: theme-factory skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/theme-factory/SKILL.md").read();

glob TASK: str = """Create a dark professional theme for a developer IDE called "Obsidian Pro".

Requirements:
- Base: very dark charcoal background (#0D1117), not pure black
- Primary accent: electric violet (#7C3AED) for active tabs, selections, buttons
- Secondary accent: amber (#F59E0B) for warnings and highlights
- Syntax highlighting:
  - Keywords: electric violet (#7C3AED)
  - Strings: emerald green (#10B981)
  - Comments: muted gray (#6B7280, italic)
  - Numbers: amber (#F59E0B)
  - Functions: cyan (#06B6D4)
  - Types: coral (#F87171)
- Font: "JetBrains Mono" 14px, line height 1.6
- Sidebar: slightly lighter (#161B22), border (#21262D)
- Terminal: black background (#0A0A0A), green text (#00FF41) for retro feel
- Output as a complete VS Code theme JSON and a preview description markdown
- Save as obsidian_pro/theme.json and obsidian_pro/preview.md""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[bash, write_file, read_file],
    max_react_iterations=15
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Generate and save the complete theme artifact.";
sem run_task.skill_text = "Complete skill instructions for theme creation, color theory, and IDE configuration formats.";
sem run_task.user_task = "The specific theme the user wants created, with all color, typography, and styling requirements.";

with entry {
    setup();
    print("=== BENCHMARK: theme-factory ===");
    print(f"Skill size: {len(SKILL_TEXT)} chars");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True,
     result = "";

with entry {
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected: list = ['obsidian_pro/theme.json'];
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

    show_results("theme-factory-baseline", success);
    show_context_breakdown();
}