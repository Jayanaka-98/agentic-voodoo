"""Benchmark: brand-guidelines skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/brand-guidelines/SKILL.md").read();

glob TASK: str = """Create comprehensive brand guidelines for a fintech startup called "Nexus Pay".

Brand positioning: Nexus Pay is a B2B payment infrastructure company — serious, trustworthy,
developer-first. Competitors are Stripe and Brex. They want to feel modern and technical
without being cold or corporate.

Requirements:
- Brand story: 2-paragraph mission statement emphasizing developer experience and trust
- Logo usage: primary horizontal logo rules, minimum sizes, clear space, do/don't examples (described)
- Color palette:
  - Primary: Nexus Navy (#0F2040), Electric Blue (#0066FF)
  - Secondary: Slate (#64748B), Mist (#F1F5F9)
  - Semantic: Success (#10B981), Warning (#F59E0B), Error (#EF4444)
- Typography: Inter for UI (weights 400/600/700), IBM Plex Mono for code/numbers
- Voice & tone: 5 principles with examples of right vs wrong copy
- Photography style guidelines: real developers, candid not posed, dark office environments
- Icon style: outlined, 2px stroke, rounded corners
- Anti-patterns: 10 things never to do with the brand
- Save as nexus_pay_brand_guidelines.md""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[bash, write_file, read_file],
    max_react_iterations=15
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Produce and save the complete brand guidelines document.";
sem run_task.skill_text = "Complete skill instructions for brand guideline creation, visual identity, and documentation standards.";
sem run_task.user_task = "The specific brand guidelines document the user wants created, with all brand context and requirements.";

with entry {
    setup();
    print("=== BENCHMARK: brand-guidelines ===");
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
    _expected: list = ['nexus_pay_brand_guidelines.md'];
    _min_kb: int    = 3;
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

    show_results("brand-guidelines-baseline", success);
    show_context_breakdown();
}