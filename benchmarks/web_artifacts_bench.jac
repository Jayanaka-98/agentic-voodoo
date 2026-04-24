"""Benchmark: web-artifacts-builder skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { execute_python, bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/web-artifacts-builder/SKILL.md").read();

glob TASK: str = """Build a single-page Pomodoro timer web app as a Claude artifact.

Requirements:
- 25-minute work timer + 5-minute break timer, switchable via tabs
- Large circular countdown display (minutes:seconds) in the center
- Start / Pause / Reset buttons
- Visual: ring fills up as time progresses (SVG stroke-dashoffset animation)
- Plays a soft chime when timer completes (use Web Audio API, no external files)
- Tracks session count — shows "Session 3 of 4" before long break
- Auto-switch to break after work session completes
- Dark mode default: background #1A1A2E, timer ring #E94560, text white
- Built with React + TypeScript + Tailwind CSS + shadcn/ui components
- Must bundle into a single self-contained HTML file
- Avoid purple gradients and centered-everything layouts""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[execute_python, bash, write_file, read_file],
    max_react_iterations=30
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Initialize project, build components, bundle, and produce final artifact.";
sem run_task.skill_text = "Complete skill instructions for web artifact creation using React, Tailwind CSS, and shadcn/ui with bundling.";
sem run_task.user_task = "The specific web app the user wants built as a self-contained artifact.";

with entry {
    setup();
    print("=== BENCHMARK: web-artifacts-builder ===");
    print(f"Skill size: {len(SKILL_TEXT)} chars");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True,
     result = "";

with entry {
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected: list = ['pomodoro_timer.html'];
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

    show_results("web-artifacts-baseline", success);
    show_context_breakdown();
}