"""Benchmark: webapp-testing skill — end-to-end task baseline measurement."""

import from measure { setup, show_results, show_context_breakdown }
import from tools { execute_python, bash, write_file, read_file }

glob SKILL_TEXT: str = open("skills/skills/webapp-testing/SKILL.md").read();

glob TASK: str = """Write a complete Playwright test suite for an e-commerce checkout flow.

Target app: https://demo-shop.example.com (mock URL — write tests assuming this URL)

Test cases to cover:
1. Happy path: add item to cart → proceed to checkout → fill shipping form → place order → see confirmation
2. Empty cart: clicking checkout with empty cart shows "Your cart is empty" message
3. Invalid credit card: entering card number 4111111111111112 shows "Invalid card" error
4. Required fields: submitting checkout form with empty email shows validation error
5. Quantity update: changing item quantity in cart updates subtotal correctly

Requirements:
- Use Playwright with Python (pytest-playwright)
- Each test must be independent (no shared state)
- Use page object model — create a CartPage, CheckoutPage class
- Add fixtures for browser setup and teardown
- Tests must run headless
- Save as tests/test_checkout.py and tests/pages.py
- Run the tests and show results""";

"""Execute the skill instructions to complete the user's task using available tools."""
def run_task(skill_text: str, user_task: str) -> str by llm(
    tools=[execute_python, bash, write_file, read_file],
    max_react_iterations=25
);

sem run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Write and run the complete test suite.";
sem run_task.skill_text = "Complete skill instructions for Playwright test development, patterns, and best practices.";
sem run_task.user_task = "The specific test suite the user wants built, with all test cases and requirements.";

with entry {
    setup();
    print("=== BENCHMARK: webapp-testing ===");
    print(f"Skill size: {len(SKILL_TEXT)} chars");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True,
     result = "";

with entry {
    # ── Artifact validation ──────────────────────────────────────────────────
    import os;
    _expected: list = ['tests/test_checkout.py'];
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

    show_results("webapp-testing-baseline", success);
    show_context_breakdown();
}