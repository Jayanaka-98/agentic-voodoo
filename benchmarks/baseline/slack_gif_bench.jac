"""Benchmark: slack-gif-creator skill — end-to-end task baseline measurement."""

import os;
import from ..lib.measure { setup, show_results, show_context_breakdown }
import from ..lib.tools { execute_python, bash, write_file, read_file }

glob _SKILLS_ROOT: str = os.environ.get("SKILLS_ROOT", "skills/anthropic/skills");
glob SKILL_TEXT: str = open(f"{_SKILLS_ROOT}/slack-gif-creator/SKILL.md").read();

glob TASK: str = """Create an animated Slack emoji GIF of a rocket ship launching.

Requirements:
- Canvas: 128x128px (standard Slack emoji size)
- Animation: 24 frames at 80ms per frame (~3s loop)
- Frame 1-8: rocket sitting on launch pad, countdown effect (3...2...1)
- Frame 9-16: rocket lifting off with growing flame/exhaust plume below
- Frame 17-24: rocket accelerating upward, trail of particles fading behind it
- Colors: rocket body silver (#C0C0C0), flame orange (#FF6B00) to yellow (#FFD700),
  space background deep navy (#0A0A1A), stars as white dots
- The rocket should be clearly readable at 128px
- Loop seamlessly (frame 24 transitions back to frame 1)
- Save as rocket_launch.gif""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[execute_python, bash, write_file, read_file],
    max_react_iterations=25
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Create and save the animated GIF.";
sem run_task.skill_text = "Complete skill instructions for animated GIF creation using PIL/Pillow, frame construction, and Slack emoji constraints.";
sem run_task.user_task = "The specific animated emoji the user wants created, with all animation and visual requirements.";

with entry {
    setup();
    print("=== BENCHMARK: slack-gif-creator ===");
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
    _expected: list = ['rocket_launch.gif'];
    _min_kb: int    = 50;
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

    show_results("slack-gif-baseline", success);
    show_context_breakdown();
}