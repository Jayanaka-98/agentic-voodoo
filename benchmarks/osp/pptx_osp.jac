"""OSP + byLLM lift of the pptx skill.

Faithful lift of skills/skills/pptx/SKILL.md.
Task matches pptx_bench.jac (GreenFlow pitch deck).

Demonstrates Flow x Mind primitives:
  Pipe + Extract  : parse_request, plan_deck (creative inside typed contract)
  Loop + Generate : design_slide per slide
  Pipe + Generate : write_pptx_code (Python source)
  Pipe + Invoke   : execute_python
  Route           : Dispatch over PPTXMode (READ / EDIT / CREATE_NEW)
"""

import from ..lib.measure { setup, show_results, show_context_breakdown }
import from ..lib.tools { execute_python, bash, write_file, read_file, execute_node }
import os;

# ── Task (verbatim from pptx_bench.jac) ───────────────────────────────────────

glob TASK: str = """Create a 5-slide investor pitch deck for a climate tech startup called "GreenFlow".

Requirements:
- Slide 1: Title slide — company name, tagline "Turning carbon into opportunity", dark navy background
- Slide 2: Problem — current carbon tracking is expensive and inaccurate (3 bullet points)
- Slide 3: Solution — AI-powered carbon measurement platform (diagram description + 3 benefits)
- Slide 4: Traction — 12 enterprise pilots, $2.4M ARR, 3 Fortune 500 customers
- Slide 5: Ask — raising $8M Series A, use of funds breakdown
- Color palette: navy (#0A1628), emerald (#10B981), white. Bold typography, minimal bullets.
- Save as greenflow_pitch.pptx""";

# ── Typed contracts ───────────────────────────────────────────────────────────

enum PPTXMode { READ, EDIT, CREATE_NEW }

sem PPTXMode.READ = "Extract text/content from an existing pptx";
sem PPTXMode.EDIT = "Modify an existing pptx via template";
sem PPTXMode.CREATE_NEW = "Build a new pptx from scratch";

obj PPTXTask {
    has mode: PPTXMode;
    has input_file: str;
    has output_file: str;
    has user_intent: str;
}
sem PPTXTask = "Structured representation of a pptx task extracted from a user request.";
sem PPTXTask.input_file = "Input pptx path (empty when creating from scratch).";
sem PPTXTask.output_file = "Output filename the user wants the artifact saved as.";
sem PPTXTask.user_intent = "One-sentence summary of what the user wants.";

obj ColorPalette {
    has primary: str;
    has secondary: str;
    has accent: str;
}
sem ColorPalette = "Three-color palette as hex strings (e.g. '#0A1628').";

obj SlideSpec {
    has number: int;
    has kind: str;
    has title: str;
    has subtitle: str;
    has bullets: list[str];
    has stats: list[str];
    has notes: str;
}
sem SlideSpec.kind = "One of: 'title', 'problem', 'solution', 'traction', 'ask', 'content', 'closing'.";
sem SlideSpec.subtitle = "Optional subtitle / tagline (empty string if none).";
sem SlideSpec.bullets = "Bullet points as separate strings (empty list if not bulleted).";
sem SlideSpec.stats = "Big-number stats to highlight (e.g. ['$2.4M ARR', '12 pilots']) or empty list.";
sem SlideSpec.notes = "Speaker notes / additional content as a single paragraph.";

obj DeckPlan {
    has title: str;
    has palette: ColorPalette;
    has font_header: str;
    has font_body: str;
    has slides: list[SlideSpec];
    has design_motif: str;
}
sem DeckPlan = "Complete plan for a pptx deck: palette, fonts, all slides, and a unifying visual motif.";
sem DeckPlan.font_header = "Header font name (e.g. 'Arial Black', 'Georgia').";
sem DeckPlan.font_body = "Body font name (e.g. 'Calibri', 'Arial').";
sem DeckPlan.design_motif = "Single distinctive visual element repeated across slides (e.g. 'thick left border in accent color', 'icon-in-circle next to titles').";

# ── byLLM functions ───────────────────────────────────────────────────────────

"""Extract a structured PPTXTask from the user's natural-language request."""
def parse_request(user_task: str) -> PPTXTask by llm();
sem parse_request = "Identify the pptx mode (READ / EDIT / CREATE_NEW). Pull out output filename and user intent.";

"""Plan the deck content from the parsed task."""
def plan_deck(task: PPTXTask, raw_user_task: str) -> DeckPlan by llm();
sem plan_deck = "Produce a DeckPlan covering all slides described in raw_user_task. Match the user's exact figures, colors, and slide titles. Pick a content-informed palette per the SKILL guidance — avoid generic blue. Pick a header/body font pairing with personality. Define a single repeating visual motif. Each SlideSpec gets a matching kind ('title', 'problem', 'solution', 'traction', 'ask').";

"""Generate Python (python-pptx) source that builds the deck from the plan."""
def write_pptx_code(plan: DeckPlan, output_path: str) -> str by llm();
sem write_pptx_code = "Return ONLY raw runnable Python source (no markdown fences, no triple backticks, no language tags, no surrounding prose). Imports MUST be explicit and complete: `from pptx import Presentation`, `from pptx.util import Inches, Pt, Emu`, `from pptx.dml.color import RGBColor`, `from pptx.enum.shapes import MSO_SHAPE` if used, `from pptx.enum.text import PP_ALIGN` if used. Reference only symbols you imported. Apply plan.palette to slide backgrounds and accent shapes. Apply plan.font_header to titles (36-44pt bold), plan.font_body to body text (14-16pt). Add the design_motif as a repeated shape on every slide. For each SlideSpec, render title + (subtitle if set) + (stats as large callouts if set) + (bullets if set). Save to output_path.";

"""Fix a python-pptx script that errored. Output corrected Python only."""
def fix_pptx_code(broken_code: str, error_output: str, plan: DeckPlan, output_path: str) -> str by llm();
sem fix_pptx_code = "Diagnose the error in error_output and return a CORRECTED full Python script (no markdown fences). Common errors: missing imports (add `from pptx.enum.shapes import MSO_SHAPE`, `from pptx.enum.text import PP_ALIGN`, `from pptx.dml.color import RGBColor` as needed); RGBColor expects 3 ints not a hex string; Inches/Pt/Emu units mismatched; layout index out of range. Preserve the deck plan content; just fix the code so it runs and writes output_path.";

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

node ParseRequest    { has description: str = "Extract structured PPTXTask"; }
node Dispatch        { has description: str = "Route over PPTXMode"; }
node CreateNewDeck   { has description: str = "Plan + generate Python + execute (CREATE_NEW)"; }
node ReadDeck        { has description: str = "markitdown text extraction (READ)"; }
node EditDeck        { has description: str = "template-based editing (EDIT)"; }

# ── Walker ────────────────────────────────────────────────────────────────────

walker PPTXAgent {
    has user_task: str = "";
    has task: PPTXTask | None = None;
    has plan: DeckPlan | None = None;
    has code: str = "";

    can step_parse with ParseRequest entry {
        self.task = parse_request(self.user_task);
        print(f"[1] Parsed: mode={self.task.mode.name}, output={self.task.output_file}");
        visit [-->];
    }

    can step_dispatch with Dispatch entry {
        if self.task is None { return; }
        mode = self.task.mode;
        print(f"[2] Dispatching {mode.name}");
        if mode == PPTXMode.CREATE_NEW {
            visit [-->][?:CreateNewDeck];
        } elif mode == PPTXMode.READ {
            visit [-->][?:ReadDeck];
        } elif mode == PPTXMode.EDIT {
            visit [-->][?:EditDeck];
        }
    }

    can step_create with CreateNewDeck entry {
        if self.task is None { return; }
        self.plan = plan_deck(self.task, self.user_task);
        if self.plan is None { return; }
        print(f"[3] Plan: {len(self.plan.slides)} slides, palette=({self.plan.palette.primary}/{self.plan.palette.secondary}/{self.plan.palette.accent})");

        out_path = self.task.output_file;
        raw = write_pptx_code(self.plan, out_path);
        self.code = _strip_fences(raw);
        print(f"[4] Generated Python: {len(self.code)} chars");

        stdout = execute_python(self.code);
        artifact_exists = os.path.exists(out_path);

        # Loop primitive: bounded retry on execution failure
        max_retries = 2;
        attempts = 0;
        while not artifact_exists and attempts < max_retries {
            attempts = attempts + 1;
            print(f"[5.{attempts}] Retry: stdout='{stdout[:200]}'");
            raw_fix = fix_pptx_code(self.code, stdout, self.plan, out_path);
            self.code = _strip_fences(raw_fix);
            stdout = execute_python(self.code);
            artifact_exists = os.path.exists(out_path);
        }

        size = os.path.getsize(out_path) if artifact_exists else 0;
        print(f"[6] Final: artifact_exists={artifact_exists}, size={size} bytes, retries={attempts}");
    }

    can step_read with ReadDeck entry {
        print("[stub] READ branch (markitdown extraction) — out of scope for this benchmark task");
    }
    can step_edit with EditDeck entry {
        print("[stub] EDIT branch (template editing) — out of scope for this benchmark task");
    }
}

# ── Entry ─────────────────────────────────────────────────────────────────────

with entry {
    setup();
    print("=== BENCHMARK: pptx (OSP + byLLM lift) ===");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True;

with entry {
    try {
        n_parse = ParseRequest();
        n_dispatch = Dispatch();
        n_create = CreateNewDeck();
        n_read = ReadDeck();
        n_edit = EditDeck();

        root ++> n_parse ++> n_dispatch;
        n_dispatch ++> n_create;
        n_dispatch ++> n_read;
        n_dispatch ++> n_edit;

        agent = n_parse spawn PPTXAgent(user_task=TASK);
    } except Exception as e {
        print(f"ERROR: {e}");
        success = False;
    }
}

with entry {
    _expected: list = ['greenflow_pitch.pptx'];
    _min_kb: int    = 50;
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

    show_results("pptx-osp", success);
    show_context_breakdown();
}
