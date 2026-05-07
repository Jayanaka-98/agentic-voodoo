# Slide Plan — *Skills are Programs*

PhD summer research proposal · target venue: ASPLOS-26.
~20 slides for a lab/committee meeting.

The deck is structured around two contributions and two research questions:
- **RQ1** — *runtime substrate*: typed graph decomposition outperforms prose on adherence, latency, and tokens — especially as model capability shrinks.
- **RQ2** — *authoring substrate*: prose stays the source language; OSP becomes the target. The PhD is the compiler in between.

---

## Slide 1 — Title

**Skills are Programs**
*The runtime substrate, the authoring substrate, and why the field has confused them.*

Subtitle: PhD summer research proposal · target venue: ASPLOS-26.

---

## Slide 2 — The frame

Single sentence, large type:

> **Every successful language story in computing has separated the substrate authors write from the substrate the runtime executes.**

Below it, four pairs:
```
Source language       Target language
─────────────────────────────────────
C                  →  assembly
Python             →  C / bytecode
SQL                →  relational algebra
Skills.md          →  ???
```

**Talking point:** the agent ecosystem currently treats Skills.md as both source *and* target. That's the design choice this proposal interrogates.

---

## Slide 3 — What is an agent?

> *"An agent is an LLM with a context designed to achieve a specific outcome using non-weight-derived information."*

Five-layer context box, with **Acquired expertise (Skills.md)** highlighted:

1. System prompt
2. User prompt (task + format)
3. Tool descriptions
4. **Acquired expertise (Skills.md)**
5. Accumulated intermediate context

**Talking point:** of the five inputs, one is consulted on every step, authored by humans, unbounded in size, and the way we currently author it is structurally the same as how the runtime executes it.

---

## Slide 4 — Skills.md today

Real `SKILL.md` excerpt (openclaw `healthcheck`, 246 lines). Wall of prose.

Caption: *"This is how the field ships expert knowledge to agents."*

Three stats below:
- hermes-agent: 153 SKILL.md files / 1.77 MB prose
- openclaw: 98 files / 570 KB
- anthropics/skills: 17 canonical skills

**Talking point:** this is the dominant artifact. It works on frontier models. The question is *why* it works and what happens when it doesn't.

---

## Slide 5 — The two research questions

Bold, centered, side by side:

```
RQ1 — Runtime substrate
Does typed graph decomposition of
skill execution produce better adherence,
latency, and token efficiency than prose —
especially as model capability decreases?

RQ2 — Authoring substrate
Can those runtime benefits be made accessible
to skill authors who do not write code?
```

**Talking point:** RQ1 asks whether prose is the wrong *target*. RQ2 asks whether prose is the right *source*. The thesis is that the answer to both is the same — *prose is the right source, the wrong target, and we've been treating them as the same thing.*

---

## Slide 6 — RQ1 setup: four failure modes of prose-as-target

2×2 grid:

| | |
|---|---|
| **Stochasticity** — per-step error compounds across trajectories | **Ambiguity** — same prose, different reading by different models |
| **Lost-in-the-middle** — skill drifts into the attention dead zone | **Token wall + dilution** — compaction silently mutilates the skill |

Caption: *each failure mode shows up at a different primitive — Drift on Generate, Babel on prose contracts that should be Extract, Oblivion on monolithic Pipe-without-decomposition, Wall on context that should never have grown.*

**Talking point:** four symptoms. We'll show shortly they share one cause.

---

## Slide 7 — Symptoms, briefly

Compressed visual evidence — one chart per failure mode, four small panels:

- **Stochasticity:** compounding-adherence curve (99/95/90% per-step → 74/21/4% at step 30)
- **Ambiguity:** prose-mass bar chart across submodules (1.77M / 570K / 17K / 9K chars)
- **Lost-in-the-middle:** MTIR % across 16 anthropics/skills (86–99%)
- **Token wall:** *"17 providers · 2,923 lines of compaction code · `PRUNE_PROTECTED_TOOLS = ["skill"]`"*

**Talking point:** every team in the ecosystem has independently shipped a workaround for one of these four. None of the workarounds are fixes.

---

## Slide 8 — The unifying diagnosis

Two-column table:

| Layer in a skill | Right substrate |
|---|---|
| Workflow structure | a graph |
| Output contracts | a type system |
| Semantic guidance | scoped LLM annotations |
| Safety invariants | code |

Caption: *"Four orthogonal concerns collapsed into one prose blob. Every concern pays the cost of every other concern's failure mode."*

**Talking point:** the four symptoms aren't independent — they're consequences of a single design choice.

---

## Slide 9 — The substrate: 7 primitives (Flow × Mind)

**Use the Flow × Mind figure here.**

```
   Flow                        Mind
   ────────                    ─────────
   Pipe        ─→              Generate    ✏
   Route       ⇄                Extract     ⊕
   Loop        ↻                Invoke      🔧
   Spawn       ⌥
                    ×
```

Caption below:
> *Every skill workflow — every Skills.md file in every submodule of every agent framework — composes from these seven primitives.*

Programming-language analogy as a sub-table:

| Programming languages | OSP+byLLM agentic primitives |
|---|---|
| sequence, branch, loop, fork | **Pipe · Route · Loop · Spawn** |
| assign, query, side-effect | **Generate · Extract · Invoke** |

**Talking point:**
- Skill authors write prose. Underneath, the LLM is still executing as a sequence of these seven primitives.
- A `for each file in repo, summarize it` is `Loop + Generate`. A `parse this email and pull the deadline` is `Pipe + Extract`. A `run pytest, retry if it fails` is `Loop + Invoke + Route`.
- Each Mind primitive has a different stochasticity profile — *Generate* is widest, *Extract* is bounded by schema, *Invoke* is grounded by tool response. The right primitive at each node is itself an adherence decision the prose substrate hides.
- We're not adding structure. We're naming the structure that's already there.

---

## Slide 10 — Muscle memory analogy

Three cards:

**Beginner** — Consults the whole manual every step. *(Skills.md today.)*
**Practitioner** — Structure becomes muscle memory; defaults become intuition; docs are consulted selectively.
**Expert** — Same, but the structure they internalize *is* Flow × Mind. Prose appears only at nodes where ambiguity legitimately remains.

**Visual:** same person across three frames — first hunched over a thick manual, then with a typed graph and a small reference card, then operating freely with a tiny annotation here and there.

**Talking point:** OSP doesn't replace prose. It puts prose where prose belongs — attached to specific Mind nodes, not as a global manual.

---

## Slide 11 — Preliminary results: the controlled experiment

Same skill (OpenClaw `healthcheck`), same model (`gpt-4o-mini`), same tools, 5 runs each.

```
                    baseline    OSP        Δ
Prompt tokens       7,698       2,497      −68%
Wall time           140 s       27 s       5× faster
Cost                $0.00124    $0.00099   −20%
Success rate        100%        100%       —
```

**Talking point:** the token reduction is structural, not incidental. In baseline, 246 lines of skill prose are present in *every* ReAct iteration. In OSP, each `by llm()` call carries only what its primitive needs. Strong evidence for RQ1 at one operating point.

---

## Slide 12 — Preliminary results: how bloat compounds

Bar chart, 17 anthropics/skills sorted by API calls. `web-artifacts` bar is red (FAILED at 30-iteration cap). `mcp-builder` is the outlier: 23 calls, 642,250 prompt tokens.

```
internal-comms      ▌  2 calls         1,995 tokens
brand-guidelines    ▌  2 calls         3,080 tokens
pptx                ▌▌▌▌  5 calls     27,340 tokens
xlsx                ▌▌▌▌▌▌  6 calls   32,581 tokens
webapp-testing      ▌▌▌▌▌▌▌  7 calls  38,196 tokens
web-artifacts       ▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌  30 calls   112,500 tokens   [FAILED]
mcp-builder         ▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌  23 calls  642,250 tokens   ★ outlier
```

**Talking point:** skill text is a *static floor*. ReAct history stacks on top of it every iteration. Iteration count drives total cost — and stochasticity inflates iteration count. This is the failure mode RQ1 needs to characterize across capability tiers.

---

## Slide 13 — RQ1 closure: what's left

Three remaining gaps:

1. **Adherence eval.** Current benchmarks measure artifact presence, not whether the agent followed the spec.
2. **Capability sweep.** All evidence is at one model tier. The thesis predicts the OSP advantage *widens* as capability shrinks — needs to be tested.
3. **Generalization.** Healthcheck is one skill. Need 3–5 more multi-step skills to confirm.

Tiny chart: predicted OSP-advantage curve across capability tiers, marked "to be measured."

**Talking point:** this is summer-scoped work. RQ1 closes by the end of summer.

---

## Slide 14 — The accessibility tension (RQ2 setup)

Large, centered, two lines:

> **Skill authors are not engineers.**
> **Engineers do not author skills.**

Two columns below:

```
Why Skills.md exists                Why OSP wins at runtime
─────────────────────                ───────────────────────
Anyone can write Markdown            Typed graphs bound stochasticity
No language to learn                 Each node has a small decision surface
No types to satisfy                  Compaction has nothing to dilute
Reviewable by domain experts         Adherence checkable mechanically
```

**Talking point:** the case for prose at authoring time is just as strong as the case against prose at runtime. Both are real. RQ2 is what to do about it.

---

## Slide 15 — RQ2: three plausible resolutions

Three cards, with the first one marked **PROPOSED**:

```
A. Auto-lift  ★             B. Layered authoring         C. Tiered ecosystem
   ──────────                  ─────────────────             ──────────────────
   Authors write prose.        Authors write a hybrid:       Power-users write OSP.
   A compiler (LLM-assisted)   workflow skeleton in OSP +    Casual users accept
   translates Skills.md        prose at semantic-guidance    Skills.md runtime cost.
   to OSP at load time.        nodes.
                                                              (Honest but uninspiring —
   ★ PROPOSED                  fallback                       does not answer RQ2)
```

**Talking point:** prose becomes the source language; OSP becomes the IR. The same trick C pulled on assembly. Lines up with ASPLOS framing — "compile X to Y" is a programming-systems contribution.

---

## Slide 16 — RQ2 worked example

Side by side:

**Left:** a real 30-line `SKILL.md` excerpt (something simple — `summarize` skill).

**Right:** the OSP graph an auto-lifter would target — 3 nodes, typed inputs/outputs, primitive-tagged:

```
[Pipe + Extract]  parse_task(user_prompt) → TaskSpec
[Loop + Invoke]   for f in TaskSpec.files: read_file(f)
[Pipe + Generate] summarize(file_contents, TaskSpec) → Summary
```

Below: open questions a summer prototype must answer:
- **Lifting fidelity:** does the lifted OSP retain the 5× runtime win?
- **Human cleanup cost:** how much manual editing does the LLM-translator output need?
- **Prose-feature coverage:** which Skills.md patterns lift cleanly, which don't?

**Talking point:** this is the sketch. The summer prototype turns the question marks into measurements.

---

## Slide 17 — Related work positioning

3×2 grid:

| | What it offers | Why it's not enough |
|---|---|---|
| **DSPy** | Typed signatures replace prompts | Mind primitives without Flow; programmer-facing |
| **LangGraph** | Graph topology for agents | Flow primitives without Mind; no type system |
| **LMQL / Guidance** | Constrained generation | Per-call constraint, not workflow-level |
| **Anthropic Skills** | Standardized prose format | The substrate this proposal critiques |
| **OSP (origin)** | Spatial programming primitives | Not yet applied to skill execution |
| **byLLM (Jaseci)** | Scoped LLM calls in Jac | Engineering substrate; this work establishes the *research case* |

One-line differentiation:
> *DSPy gives Mind primitives without Flow. LangGraph gives Flow primitives without Mind. OSP+byLLM gives both, scoped per node.*

**Talking point:** every existing piece addresses one half of the substrate question. None separates source from target. That's the contribution.

---

## Slide 18 — Summer scope (12 weeks)

Two-column timeline:

**RQ1 closure (weeks 1–6)**
1. Define + implement skill-adherence metric. *(wk 1–2)*
2. Run adherence eval on existing 17-skill suite. *(wk 3)*
3. Capability sweep — healthcheck across 5 model tiers. *(wk 4–5)*
4. Generalize — port 3 more skills to OSP, replicate. *(wk 6)*

**RQ2 prototype (weeks 7–12)**
5. Build minimal `SKILL.md → OSP` auto-lifter (LLM-translator). *(wk 7–9)*
6. Run on 5–10 anthropics/skills, measure runtime retention + cleanup cost. *(wk 10–11)*
7. Write up: paper-shaped result on RQ1, position/workshop paper on RQ2. *(wk 12)*

**Talking point:** RQ1 closes in 6 weeks because most of the infrastructure is built. RQ2 is the open question the rest of the PhD develops.

---

## Slide 19 — Threats to validity

Five honest concerns, named upfront:

1. **Authoring-cost may dominate runtime savings.** Mitigated by RQ2 (auto-lift). Open if RQ2 fails.
2. **Healthcheck may not generalize.** Mitigated by week-6 generalization study.
3. **Adherence metric may be hard to define crisply.** Plan: start with step-coverage on skills with explicit ordering; refine from there.
4. **Auto-lifter quality may be capability-dependent.** Plan: measure across translator-LLM tiers, characterize the floor.
5. **Prose-output skills (brand-guidelines, internal-comms) may not benefit from OSP.** Acknowledged scope limit — OSP targets workflow-heavy skills, not artifact-as-prose skills.

**Talking point:** these are the questions the committee would raise. Naming them explicitly turns objections into engagement.

---

## Slide 20 — Take-home

Three lines, large type:

> **Skills are programs.**
>
> **Programs have a source language and a target language. The agent ecosystem has confused them.**
>
> **Prose is the right source. Typed Flow × Mind graphs are the right target. The PhD is about the compiler in between.**

Bottom: contributions delivered (RQ1 partial), contributions proposed (RQ1 closure + RQ2 prototype), target venue (ASPLOS-26), repo URL.

---

## Chart sources (all reproducible from this repo)

| Chart | Source |
|---|---|
| Compounding adherence (slide 7a) | synthetic; `[p**n for n in range(31)]` for p ∈ {0.99, 0.95, 0.90} |
| Prose mass per submodule (slide 7b) | `find … -iname SKILL.md \| wc -c` per submodule |
| MTIR % across skills (slide 7c) | [benchmarks/results/20260424_160218/summary.md](benchmarks/results/20260424_160218/summary.md) "Context Composition" |
| Token-wall infographic (slide 7d) | pi-mono `overflow.ts` (17 providers); compaction LOC counts |
| Healthcheck experiment (slide 11) | [examples/experiment/aggregate_results.json](examples/experiment/aggregate_results.json) |
| Bloat compounds (slide 12) | [benchmarks/results/20260424_160218/summary.md](benchmarks/results/20260424_160218/summary.md) "Token Usage" |
| Predicted capability sweep (slide 13) | predicted; flag clearly as the experiment to run |

---

## Three-act structure (for self-review)

- **Act I — diagnosis (slides 1–8):** prose is the wrong runtime substrate; the four failure modes share one cause.
- **Act II — runtime fix (slides 9–13):** Flow × Mind primitives + preliminary evidence + what's left to close RQ1.
- **Act III — the open question (slides 14–20):** prose is the right authoring substrate; the PhD is the compiler that bridges the two.
