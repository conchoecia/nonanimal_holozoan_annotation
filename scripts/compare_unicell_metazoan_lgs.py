#!/usr/bin/env python3
import argparse
from collections import defaultdict
from pathlib import Path


def load_chrom_ids(path: Path):
    ids = set()
    with path.open() as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.split()
            if parts:
                ids.add(parts[0])
    return ids


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare UnicellMetazoanLGs.rbh gene lists to new annotations."
    )
    parser.add_argument("--rbh", required=True, help="Path to UnicellMetazoanLGs.rbh")
    parser.add_argument("--cow", required=True, help="COW chrom file")
    parser.add_argument("--sro", required=True, help="SRO chrom file")
    parser.add_argument("--cfr", required=True, help="CFR chrom file")
    parser.add_argument("--outdir", default=".", help="Output directory")
    args = parser.parse_args()

    rbh = Path(args.rbh)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    new_sets = {
        "COW": load_chrom_ids(Path(args.cow)),
        "SRO": load_chrom_ids(Path(args.sro)),
        "CFR": load_chrom_ids(Path(args.cfr)),
    }

    with rbh.open() as f:
        header = f.readline().rstrip("\n").split("\t")
    idx = {name: header.index(name) for name in ["gene_group", "COW_gene", "SRO_gene", "CFR_gene"]}

    out_file = outdir / "UnicellMetazoanLGs_presence.tsv"
    summary_file = outdir / "UnicellMetazoanLGs_summary.txt"

    counts = defaultdict(int)
    rows = 0

    with rbh.open() as f, out_file.open("w") as out:
        next(f)
        out.write("gene_group\tCOW_gene\tCOW_present\tSRO_gene\tSRO_present\tCFR_gene\tCFR_present\n")
        for line in f:
            parts = line.rstrip("\n").split("\t")
            gene_group = parts[idx["gene_group"]]
            row = {
                "COW_gene": parts[idx["COW_gene"]],
                "SRO_gene": parts[idx["SRO_gene"]],
                "CFR_gene": parts[idx["CFR_gene"]],
            }
            for sp in ["COW", "SRO", "CFR"]:
                gene = row[f"{sp}_gene"]
                present = 1 if gene != "nan" and gene in new_sets[sp] else 0
                row[f"{sp}_present"] = present
                counts[f"{sp}_present"] += present
                if gene != "nan":
                    counts[f"{sp}_total"] += 1
            rows += 1
            out.write(
                f"{gene_group}\t{row['COW_gene']}\t{row['COW_present']}\t"
                f"{row['SRO_gene']}\t{row['SRO_present']}\t"
                f"{row['CFR_gene']}\t{row['CFR_present']}\n"
            )

    with summary_file.open("w") as out:
        out.write(f"rows\t{rows}\n")
        for sp in ["COW", "SRO", "CFR"]:
            total = counts[f"{sp}_total"]
            present = counts[f"{sp}_present"]
            frac = present / total if total else 0
            out.write(f"{sp}_present\t{present}\n")
            out.write(f"{sp}_total\t{total}\n")
            out.write(f"{sp}_fraction\t{frac:.6f}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
