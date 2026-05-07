"""Benchmark: internal-comms skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/internal-comms/SKILL.md").read();

glob TASK: str = """Write a 3P update (Progress, Plans, Problems) for the Platform Engineering team.

Context:
- Team: Platform Engineering (6 engineers)
- Period: Week of April 14-18, 2025
- Progress: Completed Kubernetes migration for 3 remaining services, reduced p99 latency by 22%,
  shipped observability dashboard v2 with 15 new metrics
- Plans: Next week — complete SLO alerting rollout (4 services remaining), start Redis cluster
  upgrade planning, sync with security team on secret rotation policy
- Problems: Redis upgrade is blocked on procurement approval for 2 additional nodes ($3k/month),
  two engineers OOO April 21-22 which compresses sprint capacity
- Audience: Engineering leadership and cross-functional stakeholders
- Save the update as team_3p_april_18.md""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[write_file, read_file],
    max_react_iterations=15
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Produce the communication artifact and save it.";
sem run_task.skill_text = "Complete skill instructions defining format, tone, and structure for internal communications.";
sem run_task.user_task = "The specific communication the user wants written, with all context provided.";

with entry {
    setup();
    print("=== BENCHMARK: internal-comms ===");
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
    _expected: list = ['team_3p_april_18.md'];
    _min_kb: int    = 0;
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

    show_results("internal-comms-baseline", success);
    show_context_breakdown();
}