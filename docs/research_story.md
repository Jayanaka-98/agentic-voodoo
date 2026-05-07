# Beyond Skills.md: Decomposing Agent Expertise into Primitives

## What is an Agent?

An agent is an LLM with a context designed to achieve a specific outcome in an environment, using information external to its training data — that is, knowledge not derivable from its weights.

That context is composed of:

1. **System prompt** — persona, global rules.
2. **User prompt** — the task, the output format, and any initial task-specific context.
3. **Tool descriptions** — the action surface available to the agent.
4. **Acquired expertise** — `Skills.md` files: prose manuals teaching the agent how to do specific things.
5. **Accumulated intermediate context** — tool results, prior reasoning, scratchpad state.

Of these, (4) is where the open problem sits. The system prompt and tool descriptions are short and stable. The user prompt is necessarily task-specific. The accumulated context grows but is bounded by the trajectory. The skill file, however, is a knowledge artifact authored once and consulted on every step — and the way it is currently authored is structurally wrong.

## The Current Paradigm: Skills.md

The dominant mechanism for getting a general-purpose agent to perform a specialized task is to attach a natural-language manual — `Skills.md`. Expert knowledge is exposed to the agent through prose: "do this, then this, in case of X do Y." This is the substrate behind the Anthropic skills repository, OpenClaw's bundled skills, hermes-agent's 153 shipped skills, and most of the agentic ecosystem.

It works. But the way it works is fragile, and the fragility is structural rather than incidental.

## The Underlying Problem

A `Skills.md` file collapses four orthogonal concerns into a single prose document:

| Layer | What it encodes | What it should be |
|---|---|---|
| Workflow structure | step ordering, branching, loops | a graph |
| Output contracts | return shapes, schemas | a type system |
| Semantic guidance | reasoning hints, heuristics | scoped LLM annotations |
| Safety invariants | cross-cutting rules, "never do X" | code-enforced logic |

When all four concerns live in the same prose blob, every concern pays the cost of every other concern's failure mode. The LLM must re-interpret all four layers on every API call. This single design choice is the root cause behind every symptom that follows.

## Four Symptoms of the Underlying Problem

### 1. Stochasticity Compounds Across Decision Points

LLMs are stochastic; the per-step error probability is never zero. The relevant quantity is not per-step adherence but *end-to-end* adherence, which compounds multiplicatively across the trajectory. A 246-line skill encodes roughly 30 implicit decision points (which tool, in what order, with what arguments, when to stop). At per-step adherence rates of 99% / 95% / 90%, end-to-end adherence is 74% / 21% / 4% respectively.

This is why the symptom intensifies sharply on smaller models. Frontier models absorb the cost because their per-step adherence is high enough that the exponent has not yet killed them. **Small language models — the regime everyone is moving toward for cost, latency, and on-device reasons — are precisely where Skills.md collapses first.** The benchmark suite in this repo is run on `gpt-4o-mini` and already shows this: `mcp-builder` ran 23 ReAct iterations, `web-artifacts` failed outright at the 30-iteration cap, and per-call iteration counts vary substantially across runs at temperature 0.

OSP does not eliminate stochasticity — every `by llm()` node is still a sample. What it does is *narrow the surface area* over which stochasticity can do harm. A scoped node with a typed return contract has a far tighter output space than a 246-line prose skill, so the same per-token error rate produces fewer end-to-end failures. **OSP's value proposition is strongest exactly where SLMs are weakest.**

### 2. Natural Language is Ambiguous; the Cost is Paid Disproportionately by Smaller Models

Whether a model adheres to a `Skills.md` file depends not only on the model and the user prompt, but on *how the skill itself is written*. The conventional remedy is "git good at writing prose" — better prompt engineering, more careful authoring, or a stronger LLM acting as the skill author. None of these address the substrate.

Larger models tolerate ambiguous prose because they have absorbed the implicit conventions of skill files during training; they fill ambiguity gaps with the modal interpretation. Smaller models have weaker priors, so they read prose more literally and more wrongly. The 153 SKILL.md files shipped by hermes-agent (1.77 MB of prose), the 98 in OpenClaw (570 KB), and the differing house styles across these codebases are all symptoms of the same fact: prose contracts do not compose, do not type-check, and are not enforceable.

The right substrate-level fix is to **remove the ambiguity, not write better prose**. A typed return contract at a graph boundary is not open to interpretation. The prose-ambiguity tax that SLMs pay disproportionately simply disappears.

### 3. The Skill Gets Lost in the Middle

In long-context agents, the skill file is dwarfed by accumulating tool results and reasoning turns. LLMs attend more strongly to the head and tail of a long prompt than to its middle, so a skill positioned in the middle receives proportionally less attention — exactly when the agent most needs to consult it. This is well-documented in the literature.

The standard remedy is to re-inject the skill near the tail. This is precisely what hermes-agent does: when a skill is preloaded for a session, it injects an explicit activation note ("[IMPORTANT: …treat its instructions as active guidance for the duration of this session…]"). But re-injection causes duplication within the same prompt, accelerating the approach to the context window.

The deeper observation: **the skill should never need to be in the middle in the first place.** If the workflow is decomposed into typed graph nodes, each node only sees the scoped context it needs. There is no monolithic prose blob to position correctly, no decay-of-attention to mitigate, and no re-injection to budget for.

### 4. The Token Wall is Real, and Mitigations Dilute the Skill

Every modern provider enforces a context window. The pi-mono codebase ships overflow-detection regex patterns for **17 distinct providers** (Anthropic, OpenAI, Google, xAI, Groq, OpenRouter, llama.cpp, LM Studio, Copilot, MiniMax, Kimi, Cerebras, Mistral, z.ai, MiMo, Ollama, Bedrock). The token wall is not hypothetical; it is a daily operational reality.

The two standard mitigations both fail the skill, in different ways:

- **Truncation** drops tokens outright. Whatever falls out of the window is gone.
- **Compaction / summarization** rewrites the conversation into a shorter form. The skill text appears to remain, but its precise wording — the part the LLM was conditioning on — has been re-paraphrased.

Both produce the same downstream pathology: the agent continues *as if* it still has the original skill, drifts out of spec, burns iterations, and may eventually re-read the skill file from disk or simply give up. Compaction designed to *save* the context window can cause the agent to *hit* the wall faster.

The production agent codebases here all confirm this is a real failure mode rather than a theoretical one. opencode hard-codes `PRUNE_PROTECTED_TOOLS = ["skill"]` to keep skill tool calls out of the pruner. hermes-agent's 1,432-line context compressor explicitly "protects head and tail" during summarization. pi-mono ships an 839-line compaction subsystem. **Every team operating real agents has independently concluded that skills require special treatment under context pressure** — but the treatment is always a workaround, never a fix.

## What Skills.md Does Well, and Where Its Edges Are

To be fair to the existing paradigm: prose is the right substrate when the artifact *is* prose. A brand-guidelines skill whose output is a brand-guidelines document, or an internal-comms skill whose output is a status update, has a small structural surface — workflow is shallow, output schema is the document itself. The benchmarks in this repo show exactly this: small-prose skills like `internal-comms` and `brand-guidelines` complete in two API calls and modest token counts. Skills.md will not disappear for these cases, nor should it.

The argument is about the rest — the workflow-heavy, tool-heavy, multi-step skills where the four concerns above are non-trivially distinct, and where collapsing them into prose imposes the bulk of the cost.

## The Solution: Decompose Skills into Primitives

The insight: when an LLM executes a skill, the underlying execution always factors along two orthogonal axes — *how execution moves between steps* and *what happens at each step*. Naming these axes gives us a small set of primitives that compose any agentic workflow, including any `Skills.md` file ever written.

**Flow primitives** — how execution moves between nodes:

- **Pipe** — sequential composition: A → B.
- **Route** — conditional branching: A → (B | C).
- **Loop** — iterate until a condition holds.
- **Spawn** — fan out into parallel subtrajectories.

**Mind primitives** — what happens at each node:

- **Generate** — produce free-form output (text, code, prose).
- **Extract** — pull structured, typed values out of unstructured input.
- **Invoke** — call a tool against the world.

Every agentic workflow is a composition over **Flow × Mind**. A `for each file in repo, summarize it` is `Loop + Generate`. A `parse this email and pull the deadline` is `Pipe + Extract`. A `run pytest, and if it fails retry` is `Loop + Invoke + Route`. The seven primitives are not novel for novelty's sake — they are the same factoring every programming language has independently converged on (control flow × statement types), applied to a stochastic interpreter.

This parallel is precise:

| Programming languages | OSP+byLLM agentic primitives |
|---|---|
| sequence, branch, loop, fork | **Pipe · Route · Loop · Spawn** |
| assign, query, side-effect | **Generate · Extract · Invoke** |

Each Mind primitive has a different stochasticity profile, which is itself a research-grade observation. *Generate* has the widest output space and therefore the highest per-step error rate. *Extract* is bounded by a typed schema and should be measurably more reliable on the same model. *Invoke* is grounded by the tool's deterministic response. This means *the right Mind primitive at each node is itself an adherence-engineering decision* — and one that prose authors cannot make explicitly, because the prose substrate does not surface the choice.

If a `Skills.md` file is decomposed into Flow × Mind primitives, the skill becomes:

- **Distributed**: each step lives in its own scoped context window, not a shared blob.
- **Typed**: workflow structure is enforced by Flow topology, output shapes by Mind contracts (especially *Extract*), safety by ordinary code.
- **Repeatable**: per-node adherence rates do not compound exponentially because the trajectory is shorter and each node's decision surface is bounded by its primitive type.

Object-Spatial Programming (OSP) in Jac, combined with the byLLM plugin, provides exactly these seven primitives at the language level. Each `by llm()` call sees only the minimal scoped context for its node, with typed inputs and outputs. Prose appears only where it is genuinely irreducible — as scoped semantic guidance attached to a specific Mind node — rather than as a global manual the agent must re-interpret on every step.

## The Analogy

Think of `Skills.md` as a user manual. When a person first learns a skill, they consult the manual constantly. But once the skill is well-learned, three things happen:

- Mechanical steps become **muscle memory**.
- Judgment calls become **intuition**.
- Reference lookups become **selective**: consult the docs only for the part that is genuinely uncertain, not the whole manual every time.

The current Skills.md paradigm forces the agent to behave like a beginner forever — reading the entire manual on every step. The OSP paradigm models the experienced practitioner: structure is internalized as code, types are internalized as contracts, and prose is consulted only at the nodes where ambiguity legitimately remains.

## Empirical Evidence in This Repo

The thesis above is not speculative. The benchmarks in this repo establish:

- **Skill bloat is universal**: across 16 of 17 anthropics/skills benchmarks, the skill file plus task description occupies **86–99% of the initial prompt's tokens** before any task-specific work begins.
- **Bloat compounds across iterations**: `mcp-builder` consumed **642,250 prompt tokens across 23 ReAct calls** — a static skill-text floor stacked under accumulating tool results.
- **OSP wins on the same task**: on the OpenClaw `healthcheck` skill with five runs each, OSP cut average prompt tokens by **68%** (7,698 → 2,497), wall time by **5×** (140s → 27s), and cost by **20%**, with both approaches at 100% success.

These results were obtained on `gpt-4o-mini`. The thesis predicts the OSP advantage *widens* as model capability shrinks, because the symptoms in §1 and §2 intensify on smaller models. A capability-sweep experiment (mini → standard → frontier across providers) is the natural next step and would close the strongest open question in the argument.

## Interlude: The Four Horsemen of Agentic AI Design

Every agent, the moment it is handed a prose skill and pointed at a task, summons four riders. They are not specific to any framework, any provider, or any model. They are properties of the substrate itself — of trying to run a stochastic interpreter over an ambiguous manual under a finite context window. Anyone who has shipped an agent has met all four, usually without naming them.

They do not arrive together. They arrive in order. By the time the fourth shows up, the run is already lost.

### The First Horseman — **Drift**, who rides on Stochasticity

Drift is the quiet one. He does not break the agent; he merely nudges it. One token off here, one tool argument off there. On a frontier model his nudges are absorbed and forgotten. On a small model they compound: a 99% rider becomes a 4% rider over thirty steps. Drift kills slowly, by attrition, and his victims rarely notice he was there. They blame the model. They blame the prompt. They retry. Drift smiles and rides on.

### The Second Horseman — **Babel**, who rides on Ambiguity

Babel travels with a manual in his saddlebag. The manual is well-written. The manual is unambiguous *to its author*. Babel hands it to the agent and the agent reads something subtly different — a different ordering, a different default, a different interpretation of "if the file does not exist." Frontier models, having read a million manuals, guess Babel's intent correctly. Smaller models read what is actually written. Babel is the patron saint of the phrase *"but I told it to do that"* and the reason every team eventually employs an LLM to write prompts for another LLM. He laughs at this and rides on.

### The Third Horseman — **Oblivion**, who rides on Lost-in-the-Middle

Oblivion is patient. He waits for the conversation to grow. The skill file, once prominent at the head of the prompt, slides downward as tool results pile in above and below. The model's attention thins in the middle, where the skill now lives. The agent begins improvising. The skill is *technically present* — the tokens are right there — but the model is no longer reading them. Engineers, sensing Oblivion's work, paste the skill in again at the bottom. Now there are two copies. The context window shrinks faster. Oblivion is delighted. He rides on.

### The Fourth Horseman — **The Wall**, who rides on the Token Limit

The Wall does not negotiate. He arrives when the context window is full and he is not impressed by your skill file. Truncation hands him a knife and he cuts. Compaction hands him a paraphrase and he rewrites. Either way, what comes out the other side is not what went in. The agent, unaware, continues conditioning on a skill that has been silently mutilated, spec-drifts gloriously, and burns its remaining iterations chasing a ghost of the original instructions. Seventeen providers ship error patterns for The Wall's arrival. Three of the four submodules in this repo have entire subsystems dedicated to slowing him down. None of them stop him.

### The End of the Ride

The four horsemen ride together because they share a mount: a single prose blob carrying four orthogonal concerns. Kill the mount and the horsemen scatter.

- **Drift** loses his exponent when each Flow × Mind node has a small, type-bounded decision surface.
- **Babel** loses his manual when *Extract* replaces prose contracts with typed ones.
- **Oblivion** loses his middle when *Pipe* across scoped nodes replaces the monolithic blob.
- **The Wall** loses his target when each `by llm()` call carries only what its primitive needs.

That is what OSP does. Not by outrunning the horsemen — they always catch the prose — but by no longer riding the same horse.

---

## What This Research Argues

`Skills.md` is a program written in the wrong language. It works on frontier models because their per-step adherence is high enough to absorb the cost — but that is an accident of capability, not a property of the design. As the economics push toward smaller, faster, cheaper models, the substrate has to change.

Decomposing skills into the seven Flow × Mind primitives — the structure that LLMs already implicitly execute when running a skill — eliminates the four symptoms above at their source: stochasticity is bounded by per-primitive decision surfaces, ambiguity collapses into typed *Extract* contracts, attention-decay disappears with the monolithic blob, and compaction has nothing critical left to dilute.

That is the research.
