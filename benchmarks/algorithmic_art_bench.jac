"""Benchmark: algorithmic-art skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/algorithmic-art/SKILL.md").read();

glob TASK: str = """Create a generative art piece called "Deep Ocean Currents" using p5.js.

Artistic vision:
- Evoke the feeling of deep ocean thermal currents — slow, powerful, invisible forces
- Flowing particle system (800+ particles) driven by Perlin noise vector fields
- Color palette: deep navy (#0A0E1A), bioluminescent teal (#00FFD4), midnight blue (#1A1F3A), pale cyan (#7FECDC)
- Particles leave fading trails (alpha decay), creating a sense of time passing
- Occasional "pulse" events where a cluster of particles brightens and accelerates
- Canvas size: 1200x800px, dark background
- The sketch should loop indefinitely and feel meditative
- Include a subtle vignette effect at the edges
- Save as deep_ocean_currents/sketch.js and deep_ocean_currents/index.html""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[bash, write_file, read_file],
    max_react_iterations=20
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Create a complete, runnable generative art sketch.";
sem run_task.skill_text = "Complete skill instructions for algorithmic art, p5.js patterns, and generative techniques.";
sem run_task.user_task = "The specific generative art piece the user wants created, with artistic vision and technical requirements.";

with entry {
    setup();
    print("=== BENCHMARK: algorithmic-art ===");
    print(f"Skill size: {len(SKILL_TEXT)} chars");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True,
     result = "";

with entry {
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected: list = ['deep_ocean_currents/sketch.js'];
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

    show_results("algorithmic-art-baseline", success);
    show_context_breakdown();
}