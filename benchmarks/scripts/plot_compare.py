"""Grouped bar plots: baseline vs OSP across skills × metrics.

Reads the JSONL run files in the repo root and emits PNGs into
benchmarks/plots/.
"""

import json
import os
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


REPO = Path(__file__).resolve().parent.parent
OUT_DIR = Path(__file__).resolve().parent / "plots"
OUT_DIR.mkdir(exist_ok=True)

# (label_key, jsonl_filename)
SKILLS = [
    ("pdf", "pdf"),
    ("pptx", "pptx"),
    ("art", "algorithmic-art"),
]

# gpt-4o-mini pricing
COST_IN = 0.15 / 1_000_000   # USD per token
COST_OUT = 0.60 / 1_000_000


def load_runs(filename: str) -> list[dict]:
    path = REPO / filename
    if not path.exists():
        return []
    with open(path) as f:
        return [json.loads(line) for line in f if line.strip()]


def stats(runs: list[dict], key: str) -> tuple[float, float, float]:
    vals = [r[key] for r in runs]
    if not vals:
        return 0.0, 0.0, 0.0
    arr = np.array(vals, dtype=float)
    return float(np.mean(arr)), float(np.median(arr)), float(np.std(arr))


def cost_for_run(r: dict) -> float:
    return r["prompt_tokens"] * COST_IN + r["completion_tokens"] * COST_OUT


def cost_stats(runs: list[dict]) -> tuple[float, float, float]:
    vals = [cost_for_run(r) for r in runs]
    arr = np.array(vals, dtype=float)
    return float(np.mean(arr)), float(np.median(arr)), float(np.std(arr))


# ── Gather data ────────────────────────────────────────────────────────────
data = {}
RESULTS_DIR = os.environ.get("RESULTS_DIR", ".")
for short, fname in SKILLS:
    base = load_runs(f"{RESULTS_DIR}/{fname}-baseline_runs.jsonl")
    osp = load_runs(f"{RESULTS_DIR}/{fname}-osp_runs.jsonl")
    data[short] = {
        "baseline_runs": base,
        "osp_runs": osp,
        "baseline": {
            "prompt": stats(base, "prompt_tokens"),
            "completion": stats(base, "completion_tokens"),
            "total": stats(base, "total_tokens"),
            "wall_s": stats([{**r, "wall_s": r["wall_clock_ms"] / 1000} for r in base], "wall_s"),
            "cost": cost_stats(base),
        },
        "osp": {
            "prompt": stats(osp, "prompt_tokens"),
            "completion": stats(osp, "completion_tokens"),
            "total": stats(osp, "total_tokens"),
            "wall_s": stats([{**r, "wall_s": r["wall_clock_ms"] / 1000} for r in osp], "wall_s"),
            "cost": cost_stats(osp),
        },
    }


# ── Figure: 2x2 grid of grouped bars ───────────────────────────────────────
fig, axes = plt.subplots(2, 2, figsize=(11, 8))
fig.suptitle(
    "OSP vs Skills.md baseline — three skills, gpt-4o-mini, N=5\n"
    "(median values; error bars = std dev)",
    fontsize=12,
)

skills = list(data.keys())
x = np.arange(len(skills))
width = 0.35

PALETTE = {
    "baseline": "#C44E52",   # red — Skills.md
    "osp": "#4C72B0",        # blue — OSP+byLLM
}

panels = [
    ("Prompt tokens", "prompt", "tokens", axes[0][0]),
    ("Total tokens", "total", "tokens", axes[0][1]),
    ("Wall time", "wall_s", "seconds", axes[1][0]),
    ("Cost per run", "cost", "USD", axes[1][1]),
]

for title, key, unit, ax in panels:
    base_med = [data[s]["baseline"][key][1] for s in skills]
    osp_med = [data[s]["osp"][key][1] for s in skills]
    base_std = [data[s]["baseline"][key][2] for s in skills]
    osp_std = [data[s]["osp"][key][2] for s in skills]

    b1 = ax.bar(x - width / 2, base_med, width, yerr=base_std,
                label="Skills.md baseline", color=PALETTE["baseline"], capsize=4, alpha=0.92)
    b2 = ax.bar(x + width / 2, osp_med, width, yerr=osp_std,
                label="OSP + byLLM", color=PALETTE["osp"], capsize=4, alpha=0.92)

    # value labels
    for bars, vals in [(b1, base_med), (b2, osp_med)]:
        for bar, v in zip(bars, vals):
            if key == "cost":
                ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                        f"${v:.4f}", ha="center", va="bottom", fontsize=8)
            elif key == "wall_s":
                ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                        f"{v:.1f}s", ha="center", va="bottom", fontsize=8)
            else:
                ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                        f"{int(v):,}", ha="center", va="bottom", fontsize=8)

    ax.set_title(title, fontsize=11)
    ax.set_xticks(x)
    ax.set_xticklabels([s for s in skills])
    ax.set_ylabel(unit)
    ax.grid(axis="y", linestyle="--", alpha=0.4)
    ax.set_axisbelow(True)
    if key == "cost":
        ax.set_ylim(0, max(max(base_med), max(osp_med)) * 1.25)

# single legend at bottom
handles, labels = axes[0][0].get_legend_handles_labels()
fig.legend(handles, labels, loc="lower center", ncol=2, frameon=False, fontsize=10,
           bbox_to_anchor=(0.5, -0.01))

plt.tight_layout(rect=[0, 0.03, 1, 0.96])
fig.savefig(OUT_DIR / "compare_grouped_bars.png", dpi=160, bbox_inches="tight")
print(f"Saved: {OUT_DIR/'compare_grouped_bars.png'}")


# ── Single-panel version: prompt-token reduction percentage ─────────────────
fig2, ax = plt.subplots(figsize=(8, 5))
reductions = []
for s in skills:
    b = data[s]["baseline"]["prompt"][0]   # mean
    o = data[s]["osp"]["prompt"][0]
    reductions.append((1 - o / b) * 100 if b > 0 else 0)

bars = ax.bar(skills, reductions, color=["#888", "#888", "#888"], alpha=0.5)
# Highlight in primary color
for bar in bars:
    bar.set_color("#4C72B0")
    bar.set_alpha(0.9)

for bar, v in zip(bars, reductions):
    ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 1.5,
            f"{v:.0f}%", ha="center", va="bottom", fontsize=12, fontweight="bold")

ax.set_title("OSP prompt-token reduction vs baseline\n(mean across N=5, gpt-4o-mini)", fontsize=12)
ax.set_ylabel("Prompt-token reduction (%)")
ax.set_ylim(0, 100)
ax.grid(axis="y", linestyle="--", alpha=0.4)
ax.set_axisbelow(True)
plt.tight_layout()
fig2.savefig(OUT_DIR / "prompt_reduction_pct.png", dpi=160, bbox_inches="tight")
print(f"Saved: {OUT_DIR/'prompt_reduction_pct.png'}")


# ── Per-run scatter: wall time variance ────────────────────────────────────
fig3, ax = plt.subplots(figsize=(9, 5))
for i, s in enumerate(skills):
    base_w = [r["wall_clock_ms"] / 1000 for r in data[s]["baseline_runs"]]
    osp_w = [r["wall_clock_ms"] / 1000 for r in data[s]["osp_runs"]]
    ax.scatter([i - 0.18] * len(base_w), base_w, color=PALETTE["baseline"],
               s=80, alpha=0.85, label="Skills.md baseline" if i == 0 else None,
               edgecolor="white", linewidth=1)
    ax.scatter([i + 0.18] * len(osp_w), osp_w, color=PALETTE["osp"],
               s=80, alpha=0.85, label="OSP + byLLM" if i == 0 else None,
               edgecolor="white", linewidth=1)

ax.set_xticks(range(len(skills)))
ax.set_xticklabels(skills)
ax.set_ylabel("Wall time per run (s, log scale)")
ax.set_yscale("log")
ax.set_title("Per-run wall time — outliers exposed (log scale)\n"
             "Each dot = one run. Baseline tail is unbounded; OSP tail is bounded by max_retries.",
             fontsize=11)
ax.legend(loc="upper right", frameon=False)
ax.grid(axis="y", linestyle="--", alpha=0.4)
ax.set_axisbelow(True)
plt.tight_layout()
fig3.savefig(OUT_DIR / "wall_time_scatter.png", dpi=160, bbox_inches="tight")
print(f"Saved: {OUT_DIR/'wall_time_scatter.png'}")


print("\n=== Summary table ===")
print(f"{'skill':<8} {'metric':<14} {'baseline':>14} {'osp':>14}  {'OSP Δ':>10}")
for s in skills:
    for label, key in [("prompt (med)", "prompt"), ("total (med)", "total"),
                       ("wall_s (med)", "wall_s"), ("cost (mean)", "cost")]:
        b = data[s]["baseline"][key]
        o = data[s]["osp"][key]
        bv = b[1] if "med" in label else b[0]
        ov = o[1] if "med" in label else o[0]
        delta = (ov / bv - 1) * 100 if bv > 0 else 0
        print(f"{s:<8} {label:<14} {bv:>14,.4f} {ov:>14,.4f}  {delta:>+9.1f}%")
