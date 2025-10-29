#!/usr/bin/env python3
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description="Plot LICM benchmark results CSV")
parser.add_argument("csv_path", type=str, help="Path to results_*.csv from run_embench_licm.sh")
parser.add_argument("--outdir", type=str, default="plots", help="Directory to save figures")
args = parser.parse_args()

csv_path = Path(args.csv_path)
outdir = Path(args.outdir)
outdir.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(csv_path)

# Ensure numeric
for col in df.columns[1:]:
    df[col] = pd.to_numeric(df[col], errors="coerce")

bench = df["benchmark"]
x = np.arange(len(bench))
width = 0.35

# ---- Plot 1: Execution time (median) with variance ----
fig, ax = plt.subplots(figsize=(10, 5))
ax.bar(x - width/2, df["baseline_median_s"], width, label="Baseline", yerr=np.sqrt(df["baseline_var_s2"]), capsize=4)
ax.bar(x + width/2, df["licm_median_s"], width, label="LICM", yerr=np.sqrt(df["licm_var_s2"]), capsize=4)
ax.set_ylabel("Execution time (s)")
ax.set_title("Embench-LLVM LICM — Median Execution Time ± StdDev")
ax.set_xticks(x)
ax.set_xticklabels(bench, rotation=30, ha="right")
ax.legend()
fig.tight_layout()
fig.savefig(outdir / "licm_exec_time.png", dpi=200)

# ---- Plot 2: Speedup ----
fig, ax = plt.subplots(figsize=(10, 4))
ax.bar(x, df["speedup_median"], width=0.5, color="tab:green")
ax.axhline(1.0, color="gray", linestyle="--", linewidth=1)
ax.set_ylabel("Speedup (Baseline / LICM)")
ax.set_title("LICM Speedup per Benchmark (Median-based)")
ax.set_xticks(x)
ax.set_xticklabels(bench, rotation=30, ha="right")
fig.tight_layout()
fig.savefig(outdir / "licm_speedup.png", dpi=200)

# ---- Summary table in terminal ----
print("\n=== Summary (Median-based) ===")
print(df[["benchmark", "baseline_median_s", "licm_median_s", "speedup_median"]])

print(f"\n✅ Saved plots to: {outdir.resolve()}")
