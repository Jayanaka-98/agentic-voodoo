"""Benchmark: frontend-design skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/frontend-design/SKILL.md").read();

glob TASK: str = """Design and build a responsive SaaS landing page for a developer tool called "Logcraft".

Requirements:
- Hero section: bold headline "Ship with confidence", subheading about log analysis, CTA button "Start free trial"
- Features section: 3 cards — Real-time alerts, AI root cause analysis, Zero-config setup
- Social proof: logos of 5 fictional companies + a testimonial quote
- Pricing section: 3 tiers (Free, Pro $29/mo, Enterprise custom)
- Footer with nav links and "© 2025 Logcraft"
- Design: monospace font for code elements, dark sidebar aesthetic, green (#00C853) accent on white
- Must be responsive (mobile breakpoints at 768px)
- Avoid purple gradients, excessive rounded corners, and centered-everything layouts
- Save as logcraft_landing/index.html and logcraft_landing/styles.css""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[bash, write_file, read_file],
    max_react_iterations=25
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Build and save the complete frontend artifact.";
sem run_task.skill_text = "Complete skill instructions for frontend design, component structure, and visual guidelines.";
sem run_task.user_task = "The specific landing page the user wants built, with all design and content requirements.";

with entry {
    setup();
    print("=== BENCHMARK: frontend-design ===");
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
    _expected: list = ['logcraft_landing/index.html'];
    _min_kb: int    = 5;
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

    show_results("frontend-design-baseline", success);
    show_context_breakdown();
}