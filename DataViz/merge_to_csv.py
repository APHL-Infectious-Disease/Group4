#!/usr/bin/env python3
"""
Merge nf-core / pipeline outputs under a folder (e.g. 2026-04-29/) into one CSV row per
sample, shaped like Example_GAS_Genomic_Data.csv for the Shiny dashboard.

Sources used:
  - mlst/mlst/<sample>_ts_mlst.tsv  -> ST, MLST alleles (gki … yqiL)
  - emm/emmtyper/<sample>_emmtyper.tsv -> emm_Type, EMM cluster (stored in EMM_Family)
  - quast/<sample>.transposed.quast.report.tsv -> Contig_Num, N50, Longest_Contig, Total_Bases
  - fastp/fastp/<sample>_fastp.html -> linked via ReadPair_1 (relative path under the repo)

Columns present in the example but not produced by this pipeline (AMR WGS_*, surface genes,
etc.) are left empty so the dashboard keeps a stable schema.

Optional metadata CSV (--metadata): must include a Sample column; other columns are merged
into each row (e.g. Planet, Region, study notes). This is "metadata": facts about the specimen
or outbreak that the sequencer does not know — you add them for maps, filters, or provenance.
"""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path
from typing import Any


def load_example_columns(example_csv: Path) -> list[str]:
    with example_csv.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
    return header


def discover_samples(pipeline_dir: Path) -> list[str]:
    ids: set[str] = set()
    mlst_dir = pipeline_dir / "mlst" / "mlst"
    if mlst_dir.is_dir():
        for p in mlst_dir.glob("*_ts_mlst.tsv"):
            ids.add(p.stem.replace("_ts_mlst", ""))
    emm_dir = pipeline_dir / "emm" / "emmtyper"
    if emm_dir.is_dir():
        for p in emm_dir.glob("*_emmtyper.tsv"):
            ids.add(p.stem.replace("_emmtyper", ""))
    quast_dir = pipeline_dir / "quast"
    if quast_dir.is_dir():
        for p in quast_dir.glob("*.transposed.quast.report.tsv"):
            ids.add(p.name.replace(".transposed.quast.report.tsv", ""))
    return sorted(ids)


def parse_allele_cell(cell: str) -> str:
    """e.g. gki(3) -> 3, '-' -> '', gki(~) -> as stripped text."""
    cell = cell.strip()
    if not cell or cell == "-":
        return ""
    m = re.match(r"^[^(]+\(([^)]+)\)$", cell)
    if m:
        return m.group(1).strip()
    return cell


def parse_mlst(path: Path) -> dict[str, Any]:
    out: dict[str, Any] = {}
    if not path.is_file():
        return out
    with path.open(encoding="utf-8") as f:
        rows = list(csv.reader(f, delimiter="\t"))
    if len(rows) < 2:
        return out
    header = rows[0]
    data = rows[1]
    hmap = {name: i for i, name in enumerate(header)}
    if "Sequence_Type" in hmap:
        out["ST"] = data[hmap["Sequence_Type"]].strip()
    for col in ("gki", "gtr", "murI", "mutS", "recP", "xpt", "yqiL"):
        if col in hmap:
            out[col] = parse_allele_cell(data[hmap[col]])
    return out


def normalize_emm_type(raw: str) -> str:
    """EMM12.0 -> 12.0 to align with example dashboard style."""
    raw = raw.strip()
    if not raw:
        return ""
    if raw.upper().startswith("EMM"):
        return raw[3:]
    return raw


def parse_emmtyper(path: Path) -> dict[str, Any]:
    out: dict[str, Any] = {}
    if not path.is_file():
        return out
    with path.open(encoding="utf-8") as f:
        rows = list(csv.reader(f, delimiter="\t"))
    if len(rows) < 2:
        return out
    header = rows[0]
    data = rows[1]
    hmap = {name: i for i, name in enumerate(header)}
    pred = "Predicted emm-type"
    if pred in hmap:
        v = data[hmap[pred]].strip()
        out["emm_Type"] = normalize_emm_type(v) if v else ""
        if not out["emm_Type"]:
            out["emm_Type"] = "Not Found"
    cluster = "EMM cluster"
    if cluster in hmap:
        out["EMM_Family"] = data[hmap[cluster]].strip()
    return out


def parse_quast_transposed(path: Path) -> dict[str, Any]:
    out: dict[str, Any] = {}
    if not path.is_file():
        return out
    with path.open(encoding="utf-8") as f:
        rows = list(csv.reader(f, delimiter="\t"))
    if len(rows) < 2:
        return out
    header = rows[0]
    data = rows[1]
    hmap = {name: i for i, name in enumerate(header)}
    # Prefer overall "# contigs" / "Largest contig" / "Total length" (QUAST transposed layout).
    if "# contigs" in hmap:
        out["Contig_Num"] = data[hmap["# contigs"]].strip()
    if "Largest contig" in hmap:
        out["Longest_Contig"] = data[hmap["Largest contig"]].strip()
    if "Total length" in hmap:
        out["Total_Bases"] = data[hmap["Total length"]].strip()
    if "N50" in hmap:
        out["N50"] = data[hmap["N50"]].strip()
    return out


def load_metadata_csv(path: Path) -> dict[str, dict[str, str]]:
    """Sample -> {column: value} for user-provided columns."""
    by_sample: dict[str, dict[str, str]] = {}
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames or "Sample" not in reader.fieldnames:
            raise SystemExit(f"Metadata CSV must include a 'Sample' column: {path}")
        for row in reader:
            sid = (row.get("Sample") or "").strip()
            if not sid:
                continue
            by_sample[sid] = {k: (v or "").strip() for k, v in row.items() if k and k != "Sample"}
    return by_sample


def build_row(
    sample: str,
    pipeline_dir: Path,
    columns: list[str],
    metadata_by_sample: dict[str, dict[str, str]],
    pipeline_relative_prefix: str,
) -> dict[str, str]:
    row = {c: "" for c in columns}

    mlst_path = pipeline_dir / "mlst" / "mlst" / f"{sample}_ts_mlst.tsv"
    emm_path = pipeline_dir / "emm" / "emmtyper" / f"{sample}_emmtyper.tsv"
    quast_path = pipeline_dir / "quast" / f"{sample}.transposed.quast.report.tsv"

    row["Sample"] = sample

    for k, v in parse_mlst(mlst_path).items():
        if k in row:
            row[k] = str(v)

    for k, v in parse_emmtyper(emm_path).items():
        if k in row:
            row[k] = str(v)

    for k, v in parse_quast_transposed(quast_path).items():
        if k in row:
            row[k] = str(v)

    # Link to fastp HTML relative to repo root for traceability (column name is legacy).
    html_rel = f"{pipeline_relative_prefix}/fastp/fastp/{sample}_fastp.html"
    row["ReadPair_1"] = html_rel

    if sample in metadata_by_sample:
        for mk, mv in metadata_by_sample[sample].items():
            if mk in row:
                row[mk] = mv

    if not (row.get("emm_Type") or "").strip():
        row["emm_Type"] = "Not Found"

    return row


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    default_pipeline = repo_root / "2026-04-29"
    default_example = repo_root / "DataViz" / "Example_GAS_Genomic_Data.csv"
    default_out = repo_root / "DataViz" / "GAS_nfcore_merged.csv"

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pipeline-dir",
        type=Path,
        default=default_pipeline,
        help=f"Folder with mlst/, emm/, quast/, fastp/ (default: {default_pipeline})",
    )
    parser.add_argument(
        "--example-csv",
        type=Path,
        default=default_example,
        help="Dashboard example CSV whose header defines output columns",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=default_out,
        help=f"Output CSV path (default: {default_out})",
    )
    parser.add_argument(
        "--metadata",
        type=Path,
        default=None,
        help="Optional CSV keyed by Sample with Planet, Region, and other custom columns",
    )
    args = parser.parse_args()

    pipeline_dir = args.pipeline_dir.resolve()
    if not pipeline_dir.is_dir():
        raise SystemExit(f"Pipeline directory not found: {pipeline_dir}")

    columns = load_example_columns(args.example_csv.resolve())
    samples = discover_samples(pipeline_dir)
    if not samples:
        raise SystemExit(f"No samples found under {pipeline_dir} (check mlst/emm/quast outputs).")

    meta: dict[str, dict[str, str]] = {}
    if args.metadata:
        meta = load_metadata_csv(args.metadata.resolve())

    try:
        prefix = pipeline_dir.resolve().relative_to(repo_root).as_posix()
    except ValueError:
        prefix = pipeline_dir.name

    rows = [build_row(s, pipeline_dir, columns, meta, prefix) for s in samples]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} samples to {args.output.resolve()}")


if __name__ == "__main__":
    main()
