"""Benchmark: slack-gif-creator skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { execute_python, bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/slack-gif-creator/SKILL.md").read();

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
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected = ['rocket_launch.gif'];
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

    show_results("slack-gif-baseline", success);
    show_context_breakdown();
}