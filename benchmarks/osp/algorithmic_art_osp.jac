"""OSP + byLLM lift of the algorithmic-art skill.

Faithful lift of skills/skills/algorithmic-art/SKILL.md.
Task matches algorithmic_art_bench.jac (Deep Ocean Currents).

Demonstrates that OSP works for a *creative* skill, not just functional ones:
the Pipe + Generate nodes are open-ended (philosophy / sketch code), but the
graph topology + typed schemas still impose structure.

Two-stage workflow from the SKILL:
  1. Algorithmic Philosophy Creation (.md)
  2. Express in p5.js (.html + .js)
"""

import from ..lib.measure { setup, show_results, show_context_breakdown }
import from ..lib.tools { bash, write_file, read_file }
import os;

# ── Task (verbatim from algorithmic_art_bench.jac) ────────────────────────────

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

# ── Typed contracts ───────────────────────────────────────────────────────────

obj ArtTask {
    has movement_name: str;
    has output_dir: str;
    has output_js: str;
    has output_html: str;
    has user_intent: str;
}
sem ArtTask = "Structured representation of an algorithmic-art task.";
sem ArtTask.movement_name = "1-2 word name for the algorithmic philosophy/movement (e.g. 'Deep Ocean Currents').";
sem ArtTask.output_dir = "Directory to write the output files into (e.g. 'deep_ocean_currents').";
sem ArtTask.user_intent = "One-sentence summary of the user's artistic vision.";

obj AlgorithmicPhilosophy {
    has movement_name: str;
    has manifesto: str;
    has computational_motif: str;
    has parametric_emphasis: str;
    has craftsmanship_note: str;
}
sem AlgorithmicPhilosophy = "A 4-6 paragraph philosophy text describing the generative aesthetic movement.";
sem AlgorithmicPhilosophy.manifesto = "The full philosophy text — 4-6 paragraphs of poetic computational philosophy. Avoid redundancy. Emphasize craftsmanship multiple times. Algorithmic, not static.";
sem AlgorithmicPhilosophy.computational_motif = "The core computational/mathematical pattern (e.g. 'layered Perlin noise vector fields', 'recursive subdivision').";
sem AlgorithmicPhilosophy.parametric_emphasis = "What parameters drive variation (e.g. 'noise octave count, particle velocity, alpha decay rate').";
sem AlgorithmicPhilosophy.craftsmanship_note = "One paragraph explicitly stressing this should appear meticulously crafted by a master.";

obj SketchSpec {
    has canvas_w: int;
    has canvas_h: int;
    has palette: list[str];
    has particle_count: int;
    has technique: str;
    has special_effects: list[str];
    has loop_behavior: str;
}
sem SketchSpec = "Concrete plan for the p5.js sketch derived from the philosophy.";
sem SketchSpec.palette = "List of hex color strings used in the sketch.";
sem SketchSpec.technique = "Primary algorithmic technique (e.g. 'flow field with Perlin-noise-driven vectors').";
sem SketchSpec.special_effects = "Additional effects to layer in (e.g. 'pulse events', 'vignette', 'trail decay').";
sem SketchSpec.loop_behavior = "Whether/how the sketch loops (e.g. 'infinite, draw() runs continuously', 'one-shot fade out').";

# ── byLLM functions ───────────────────────────────────────────────────────────

"""Extract a structured ArtTask from the user's natural-language request."""
def parse_request(user_task: str) -> ArtTask by llm();
sem parse_request = "Identify the movement name and output directory from the request. Construct output_js and output_html paths inside output_dir (e.g. 'deep_ocean_currents/sketch.js').";

"""Stage 1 — Create the algorithmic philosophy."""
def create_philosophy(task: ArtTask, raw_user_task: str) -> AlgorithmicPhilosophy by llm();
sem create_philosophy = "Author a 4-6 paragraph algorithmic philosophy that captures the user's vision computationally. Emphasize ALGORITHMIC expression, emergent behavior, parametric variation. Repeatedly stress meticulous craftsmanship. Avoid redundancy. The philosophy should leave creative room for the implementation stage.";

"""Stage 2a — Plan the p5.js sketch from the philosophy."""
def design_sketch(philosophy: AlgorithmicPhilosophy, raw_user_task: str) -> SketchSpec by llm();
sem design_sketch = "Translate the philosophy into a concrete SketchSpec. Pull canvas size, palette, particle count, special effects from raw_user_task verbatim. The technique should embody the philosophy's computational_motif.";

"""Stage 2b — Generate the p5.js JavaScript code."""
def write_js_code(philosophy: AlgorithmicPhilosophy, spec: SketchSpec) -> str by llm();
sem write_js_code = "Return ONLY raw runnable p5.js JavaScript (no markdown fences, no triple backticks, no language tags, no surrounding prose). Implement setup() and draw() following the spec. Use the spec.palette colors. Honor spec.particle_count. Implement spec.special_effects (e.g. trail decay via low-alpha background fill, vignette via a radial gradient overlay, pulse events via a periodic intensity multiplier on a particle cluster). Make the sketch loop indefinitely. The implementation should feel like the work of a master — meticulously tuned constants, layered noise, no shortcuts.";

"""Stage 2c — Generate the HTML wrapper."""
def write_html_code(spec: SketchSpec, sketch_path: str) -> str by llm();
sem write_html_code = "Return ONLY raw HTML (no markdown fences, no triple backticks, no surrounding prose). Include the p5.js CDN script and load sketch_path as a script tag. Set body background to the darkest palette color. Match canvas dimensions to spec.canvas_w x spec.canvas_h.";

"""Strip markdown code fences from an LLM-generated code blob."""
def _strip_fences(code: str) -> str {
    s = code.strip();
    if s.startswith("```") {
        first_nl = s.find("\n");
        if first_nl > 0 { s = s[first_nl + 1:]; }
    }
    if s.endswith("```") {
        s = s[:-3];
    }
    return s.strip();
}

# ── Graph nodes ───────────────────────────────────────────────────────────────

node ParseRequest      { has description: str = "Extract ArtTask"; }
node Stage1Philosophy  { has description: str = "Generate algorithmic philosophy (.md)"; }
node Stage2Design      { has description: str = "Plan the p5.js sketch from philosophy"; }
node Stage2Implement   { has description: str = "Write JS + HTML files"; }

# ── Walker ────────────────────────────────────────────────────────────────────

walker ArtAgent {
    has user_task: str = "";
    has task: ArtTask | None = None;
    has philosophy: AlgorithmicPhilosophy | None = None;
    has spec: SketchSpec | None = None;
    has js_code: str = "";
    has html_code: str = "";

    can step_parse with ParseRequest entry {
        self.task = parse_request(self.user_task);
        print(f"[1] Parsed: movement='{self.task.movement_name}', dir={self.task.output_dir}");
        visit [-->];
    }

    can step_philosophy with Stage1Philosophy entry {
        if self.task is None { return; }
        self.philosophy = create_philosophy(self.task, self.user_task);
        if self.philosophy is None { return; }
        print(f"[2] Philosophy: {len(self.philosophy.manifesto)} chars");

        # Write the philosophy .md
        os.makedirs(self.task.output_dir, exist_ok=True);
        md_path = f"{self.task.output_dir}/philosophy.md";
        with open(md_path, "w", encoding="utf-8") as f {
            f.write(f"# {self.philosophy.movement_name}\n\n");
            f.write(self.philosophy.manifesto);
            f.write(f"\n\n## Computational Motif\n{self.philosophy.computational_motif}\n");
            f.write(f"\n## Parametric Emphasis\n{self.philosophy.parametric_emphasis}\n");
            f.write(f"\n## Craftsmanship\n{self.philosophy.craftsmanship_note}\n");
        }
        print(f"  wrote {md_path}");
        visit [-->];
    }

    can step_design with Stage2Design entry {
        if self.task is None or self.philosophy is None { return; }
        self.spec = design_sketch(self.philosophy, self.user_task);
        if self.spec is None { return; }
        print(f"[3] Spec: {self.spec.canvas_w}x{self.spec.canvas_h}, {self.spec.particle_count} particles, palette={self.spec.palette}");
        visit [-->];
    }

    can step_implement with Stage2Implement entry {
        if self.task is None or self.philosophy is None or self.spec is None { return; }

        raw_js = write_js_code(self.philosophy, self.spec);
        self.js_code = _strip_fences(raw_js);
        print(f"[4] JS: {len(self.js_code)} chars");

        sketch_basename = "sketch.js";
        raw_html = write_html_code(self.spec, sketch_basename);
        self.html_code = _strip_fences(raw_html);
        print(f"[5] HTML: {len(self.html_code)} chars");

        os.makedirs(self.task.output_dir, exist_ok=True);
        with open(self.task.output_js, "w", encoding="utf-8") as f { f.write(self.js_code); }
        with open(self.task.output_html, "w", encoding="utf-8") as f { f.write(self.html_code); }
        js_size = os.path.getsize(self.task.output_js) if os.path.exists(self.task.output_js) else 0;
        html_size = os.path.getsize(self.task.output_html) if os.path.exists(self.task.output_html) else 0;
        print(f"[6] Wrote {self.task.output_js} ({js_size} bytes), {self.task.output_html} ({html_size} bytes)");
    }
}

# ── Entry ─────────────────────────────────────────────────────────────────────

with entry {
    setup();
    print("=== BENCHMARK: algorithmic-art (OSP + byLLM lift) ===");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True;

with entry {
    try {
        n_parse = ParseRequest();
        n_phil = Stage1Philosophy();
        n_design = Stage2Design();
        n_impl = Stage2Implement();

        root ++> n_parse ++> n_phil ++> n_design ++> n_impl;

        agent = n_parse spawn ArtAgent(user_task=TASK);
    } except Exception as e {
        print(f"ERROR: {e}");
        success = False;
    }
}

with entry {
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

    show_results("algorithmic-art-osp", success);
    show_context_breakdown();
}
