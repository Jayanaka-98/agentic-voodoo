"""OSP + byLLM lift of the pdf skill.

Faithful lift of skills/skills/pdf/SKILL.md into a typed graph.
Same task as pdf_bench.jac (Q1 sales report) so results are directly comparable.

Demonstrates Flow x Mind primitives:
  Pipe + Extract  : parse_request, plan_report
  Pipe + Generate : write_pdf_code (open-ended code synthesis inside a typed contract)
  Pipe + Invoke   : execute_python (deterministic tool call)
  Route           : Dispatch over PDFOperation enum
  Loop            : op branches with retry on validation failure (one-shot here)
"""

import from ..lib.measure { setup, show_results, show_context_breakdown }
import from ..lib.tools { execute_python, bash, write_file, read_file }
import os;

# ── Task (verbatim from pdf_bench.jac so comparison is apples-to-apples) ─────

glob TASK: str = """Create a 3-page PDF report on Q1 2024 sales performance.

Requirements:
- Cover page with title, date, and company name "Acme Corp"
- Summary table showing monthly revenue: Jan $120k, Feb $145k, Mar $162k
- Key metrics section: total revenue $427k, 35% YoY growth, top product "Widget Pro"
- Professional styling with a header on each page
- Save as q1_sales_report.pdf""";

# ── Typed contracts ───────────────────────────────────────────────────────────

enum PDFOperation {
    CREATE_NEW,
    EXTRACT_TEXT,
    EXTRACT_TABLES,
    MERGE,
    SPLIT,
    ROTATE,
    WATERMARK,
    FILL_FORM,
    ENCRYPT,
    DECRYPT,
    OCR,
    EXTRACT_IMAGES
}

sem PDFOperation.CREATE_NEW = "Build a new PDF from scratch";
sem PDFOperation.EXTRACT_TEXT = "Extract text from an existing PDF";
sem PDFOperation.EXTRACT_TABLES = "Extract tabular data from an existing PDF";
sem PDFOperation.MERGE = "Combine multiple PDFs into one";
sem PDFOperation.SPLIT = "Split one PDF into multiple files";
sem PDFOperation.ROTATE = "Rotate pages in a PDF";
sem PDFOperation.WATERMARK = "Apply a watermark overlay to pages";
sem PDFOperation.FILL_FORM = "Fill out an interactive PDF form (defers to FORMS.md)";
sem PDFOperation.ENCRYPT = "Add password protection to a PDF";
sem PDFOperation.DECRYPT = "Remove password from an encrypted PDF";
sem PDFOperation.OCR = "Extract text from a scanned PDF via OCR";
sem PDFOperation.EXTRACT_IMAGES = "Extract image assets embedded in a PDF";

obj PDFTask {
    has operation: PDFOperation;
    has input_files: list[str];
    has output_file: str;
    has params: dict[str, str];
}
sem PDFTask = "Structured representation of a PDF task extracted from a user request.";
sem PDFTask.input_files = "List of input PDF paths. Empty when creating from scratch.";
sem PDFTask.output_file = "Output filename the user wants the artifact saved as.";
sem PDFTask.params = "Operation-specific parameters as string-valued dict: revenue figures, page numbers, password, headers, etc. Stringify all values.";

obj MetricEntry {
    has label: str;
    has value: str;
}
sem MetricEntry = "A single key-value metric to render in the report (e.g. label='Total Revenue', value='$427k').";

obj ReportPlan {
    has title: str;
    has company: str;
    has date_str: str;
    has table_headers: list[str];
    has table_rows: list[list[str]];
    has metrics: list[MetricEntry];
    has body_paragraphs: list[str];
    has page_count_estimate: int;
    has styling_notes: str;
}
sem ReportPlan = "Concrete content plan for a PDF report covering all required sections (cover, table, metrics, body).";
sem ReportPlan.table_headers = "Column headers for the summary table (e.g. ['Month', 'Revenue']).";
sem ReportPlan.table_rows = "Each row is a list of strings, one per column. E.g. [['Jan', '$120k'], ['Feb', '$145k']].";
sem ReportPlan.metrics = "Key/value KPI entries for the metrics section.";
sem ReportPlan.body_paragraphs = "Free-form paragraph copy beyond table and metrics.";
sem ReportPlan.styling_notes = "Notes on professional styling: fonts, colors, spacing, header on each page.";

obj ExecutionResult {
    has stdout: str;
    has artifact_exists: bool;
    has artifact_size_bytes: int;
}

# ── byLLM functions (scoped — no skill text, only sem + types) ────────────────

"""Extract a structured PDFTask from the user's natural-language request."""
def parse_request(user_task: str) -> PDFTask by llm();
sem parse_request = "Identify the PDF operation requested. Pull out output filename, input filenames if any, and operation-specific parameters (revenue figures, company name, dates, password, page numbers) into params dict.";

"""Plan the report content from the parsed task."""
def plan_report(task: PDFTask) -> ReportPlan by llm();
sem plan_report = "Produce a ReportPlan covering all required sections inferred from task.params: cover page, summary table, key metrics. Match the user's exact figures and terminology. The page_count_estimate should match what the user asked for.";

"""Generate Python code that builds the PDF using reportlab."""
def write_pdf_code(plan: ReportPlan, output_path: str) -> str by llm();
sem write_pdf_code = "Return ONLY raw runnable Python source (no markdown fences, no triple backticks, no language tags, no surrounding prose). Use reportlab.platypus (SimpleDocTemplate, Paragraph, Table, TableStyle, Spacer, PageBreak) to build the PDF from the plan and write it to output_path. Include a header on each page via PageTemplate or onPage callback. Use built-in reportlab fonts only. Never use Unicode subscript or superscript characters.";

"""Fix a reportlab script that errored. Output corrected Python only."""
def fix_pdf_code(broken_code: str, error_output: str, plan: ReportPlan, output_path: str) -> str by llm();
sem fix_pdf_code = "Diagnose the error in error_output and return a CORRECTED full Python script (no markdown fences). Common errors: missing imports (add from reportlab.lib.styles, .platypus, .lib.units, .lib.colors as needed); using styles before importing getSampleStyleSheet; wrong arg names on Paragraph/Table; TableStyle commands malformed (use list of tuples like ('GRID', (0,0), (-1,-1), 0.5, colors.grey)); writing to a path without ensuring parent dir exists. Preserve plan content; just fix the code so it runs and writes output_path.";

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

node ParseRequest    { has description: str = "Extract structured PDFTask from user prompt"; }
node Dispatch        { has description: str = "Route to the operation handler"; }

# Active branch for the benchmark task
node CreateNewReport { has description: str = "Plan + generate Python + execute (CREATE_NEW)"; }

# Stub branches: faithful coverage of all SKILL.md operations
node ExtractText     { has description: str = "pdfplumber/pypdf text extraction (EXTRACT_TEXT)"; }
node ExtractTables   { has description: str = "pdfplumber tables (EXTRACT_TABLES)"; }
node MergePdfs       { has description: str = "pypdf merge (MERGE)"; }
node SplitPdf        { has description: str = "pypdf split (SPLIT)"; }
node RotatePdf       { has description: str = "pypdf rotate (ROTATE)"; }
node WatermarkPdf    { has description: str = "pypdf watermark (WATERMARK)"; }
node FillForm        { has description: str = "FILL_FORM (defers to FORMS.md)"; }
node EncryptPdf      { has description: str = "pypdf encrypt (ENCRYPT)"; }
node DecryptPdf      { has description: str = "qpdf decrypt (DECRYPT)"; }
node OcrPdf          { has description: str = "pdf2image + pytesseract (OCR)"; }
node ExtractImagesNode { has description: str = "pdfimages (EXTRACT_IMAGES)"; }

# ── Walker ────────────────────────────────────────────────────────────────────

walker PDFAgent {
    has user_task: str = "";
    has task: PDFTask | None = None;
    has plan: ReportPlan | None = None;
    has code: str = "";
    has exec_result: ExecutionResult | None = None;

    can step_parse with ParseRequest entry {
        self.task = parse_request(self.user_task);
        print(f"[1] Parsed: op={self.task.operation.name}, output={self.task.output_file}");
        visit [-->];
    }

    can step_dispatch with Dispatch entry {
        if self.task is None { return; }
        op = self.task.operation;
        print(f"[2] Dispatching {op.name}");
        if op == PDFOperation.CREATE_NEW {
            visit [-->][?:CreateNewReport];
        } elif op == PDFOperation.EXTRACT_TEXT {
            visit [-->][?:ExtractText];
        } elif op == PDFOperation.EXTRACT_TABLES {
            visit [-->][?:ExtractTables];
        } elif op == PDFOperation.MERGE {
            visit [-->][?:MergePdfs];
        } elif op == PDFOperation.SPLIT {
            visit [-->][?:SplitPdf];
        } elif op == PDFOperation.ROTATE {
            visit [-->][?:RotatePdf];
        } elif op == PDFOperation.WATERMARK {
            visit [-->][?:WatermarkPdf];
        } elif op == PDFOperation.FILL_FORM {
            visit [-->][?:FillForm];
        } elif op == PDFOperation.ENCRYPT {
            visit [-->][?:EncryptPdf];
        } elif op == PDFOperation.DECRYPT {
            visit [-->][?:DecryptPdf];
        } elif op == PDFOperation.OCR {
            visit [-->][?:OcrPdf];
        } elif op == PDFOperation.EXTRACT_IMAGES {
            visit [-->][?:ExtractImagesNode];
        }
    }

    can step_create_new with CreateNewReport entry {
        if self.task is None { return; }
        self.plan = plan_report(self.task);
        if self.plan is None { return; }
        print(f"[3] Plan: {len(self.plan.table_rows)} table rows, {len(self.plan.metrics)} metrics, ~{self.plan.page_count_estimate} pages");

        out_path = self.task.output_file;
        raw_code = write_pdf_code(self.plan, out_path);
        self.code = _strip_fences(raw_code);
        print(f"[4] Generated Python: {len(self.code)} chars (raw {len(raw_code)})");

        stdout = execute_python(self.code);
        artifact_exists = os.path.exists(out_path);

        # Loop primitive: bounded retry on execution failure
        max_retries = 2;
        attempts = 0;
        while not artifact_exists and attempts < max_retries {
            attempts = attempts + 1;
            print(f"[5.{attempts}] Retry: stdout='{stdout[:200]}'");
            raw_fix = fix_pdf_code(self.code, stdout, self.plan, out_path);
            self.code = _strip_fences(raw_fix);
            stdout = execute_python(self.code);
            artifact_exists = os.path.exists(out_path);
        }

        size = os.path.getsize(out_path) if artifact_exists else 0;
        self.exec_result = ExecutionResult(
            stdout=stdout,
            artifact_exists=artifact_exists,
            artifact_size_bytes=size
        );
        print(f"[6] Final: artifact_exists={artifact_exists}, size={size} bytes, retries={attempts}");
    }

    # Stubs — present in the graph for faithful coverage; not exercised by Q1-report task
    can step_extract_text with ExtractText entry {
        print("[stub] EXTRACT_TEXT branch — out of scope for this benchmark task");
    }
    can step_extract_tables with ExtractTables entry {
        print("[stub] EXTRACT_TABLES branch — out of scope");
    }
    can step_merge with MergePdfs entry {
        print("[stub] MERGE branch — out of scope");
    }
    can step_split with SplitPdf entry {
        print("[stub] SPLIT branch — out of scope");
    }
    can step_rotate with RotatePdf entry {
        print("[stub] ROTATE branch — out of scope");
    }
    can step_watermark with WatermarkPdf entry {
        print("[stub] WATERMARK branch — out of scope");
    }
    can step_fill_form with FillForm entry {
        print("[stub] FILL_FORM branch (defers to FORMS.md) — out of scope");
    }
    can step_encrypt with EncryptPdf entry {
        print("[stub] ENCRYPT branch — out of scope");
    }
    can step_decrypt with DecryptPdf entry {
        print("[stub] DECRYPT branch — out of scope");
    }
    can step_ocr with OcrPdf entry {
        print("[stub] OCR branch — out of scope");
    }
    can step_extract_images with ExtractImagesNode entry {
        print("[stub] EXTRACT_IMAGES branch — out of scope");
    }
}

# ── Entry ─────────────────────────────────────────────────────────────────────

with entry {
    setup();
    print("=== BENCHMARK: pdf (OSP + byLLM lift) ===");
    print(f"Task: {TASK[:120]}...\n");
}

glob success = True;

with entry {
    try {
        # Build graph: ParseRequest -> Dispatch -> {12 op handlers}
        n_parse = ParseRequest();
        n_dispatch = Dispatch();
        n_create = CreateNewReport();
        n_etext = ExtractText();
        n_etables = ExtractTables();
        n_merge = MergePdfs();
        n_split = SplitPdf();
        n_rotate = RotatePdf();
        n_water = WatermarkPdf();
        n_form = FillForm();
        n_enc = EncryptPdf();
        n_dec = DecryptPdf();
        n_ocr = OcrPdf();
        n_eimg = ExtractImagesNode();

        root ++> n_parse ++> n_dispatch;
        n_dispatch ++> n_create;
        n_dispatch ++> n_etext;
        n_dispatch ++> n_etables;
        n_dispatch ++> n_merge;
        n_dispatch ++> n_split;
        n_dispatch ++> n_rotate;
        n_dispatch ++> n_water;
        n_dispatch ++> n_form;
        n_dispatch ++> n_enc;
        n_dispatch ++> n_dec;
        n_dispatch ++> n_ocr;
        n_dispatch ++> n_eimg;

        agent = n_parse spawn PDFAgent(user_task=TASK);

        if agent.exec_result {
            print(f"\nExecution stdout (truncated):\n{agent.exec_result.stdout[:400]}");
        }
    } except Exception as e {
        print(f"ERROR: {e}");
        success = False;
    }
}

with entry {
    # Artifact validation (same rubric as pdf_bench.jac)
    _expected: list = ['q1_sales_report.pdf'];
    _min_kb: int    = 10;
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

    show_results("pdf-osp", success);
    show_context_breakdown();
}
