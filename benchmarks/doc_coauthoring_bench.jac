"""Benchmark: doc-coauthoring skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/doc-coauthoring/SKILL.md").read();

glob TASK: str = """Review and substantially improve this draft API authentication specification.

Draft document:
---
# Auth Spec v0.1

## Overview
We need authentication for our API. Will use JWT tokens.

## Endpoints
- POST /auth/login - gets a token
- POST /auth/refresh - refreshes token
- POST /auth/logout - logs out

## Token stuff
Tokens expire after some time. We use a secret key to sign them.
Refresh tokens last longer.

## Errors
Return 401 if not authenticated.
---

Improvements needed:
- Add proper structure: executive summary, scope, terminology section
- Specify exact token formats: access token (15 min expiry, HS256), refresh token (7 days, stored httpOnly cookie)
- Document all request/response schemas with field types and validation rules
- Add security considerations section (token rotation, replay attack prevention, rate limiting)
- Add implementation notes for frontend and backend developers
- Include sequence diagrams (described in text) for login and token refresh flows
- Fix all vague language ("some time", "stuff", "longer")
- Keep in same document but expand to production-ready spec quality
- Save as auth_spec_v1.md""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[bash, write_file, read_file],
    max_react_iterations=15
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Produce and save the improved document.";
sem run_task.skill_text = "Complete skill instructions for document co-authoring, improvement, and technical writing standards.";
sem run_task.user_task = "The specific document revision task, including the original draft and all improvement requirements.";

with entry {
    setup();
    print("=== BENCHMARK: doc-coauthoring ===");
    print(f"Skill size: {len(SKILL_TEXT)} chars");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True,
     result = "";

with entry {
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected: list = ['auth_spec_v1.md'];
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

    show_results("doc-coauthoring-baseline", success);
    show_context_breakdown();
}