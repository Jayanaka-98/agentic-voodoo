# skills/custom

Local skills authored for this project. Mirrors Anthropic's
`skills/anthropic/skills/<name>/SKILL.md` layout one-for-one, so the same
loader resolves both.

## Layout

```
skills/
  anthropic/   # upstream submodule (Anthropic's skills repo)
    skills/<name>/SKILL.md
  custom/      # this dir
    <name>/SKILL.md
```

## Loading from benches

Benches resolve skills via the `SKILLS_ROOT` env var
(default `skills/anthropic/skills`). To run a bench against a custom skill,
point it here:

```bash
SKILLS_ROOT="$REPO_ROOT/skills/custom" jac run benchmarks/baseline/<bench>.jac
```

A multi-root loader (search both `skills/anthropic/skills/` and
`skills/custom/`) can be added later if needed.
