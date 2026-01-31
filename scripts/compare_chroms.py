#!/usr/bin/env python3
import argparse
from collections import defaultdict
from pathlib import Path


def read_chrom(path: Path):
    chrom_to_ids = defaultdict(set)
    all_ids = set()
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) < 2:
                continue
            pid = parts[0]
            chrom = parts[1]
            chrom_to_ids[chrom].add(pid)
            all_ids.add(pid)
    return chrom_to_ids, all_ids


def best_match(chrom_ids, other_map):
    best = None
    best_overlap = -1
    for other_chrom, other_ids in other_map.items():
        overlap = len(chrom_ids & other_ids)
        if overlap > best_overlap or (overlap == best_overlap and best is not None and other_chrom < best):
            best_overlap = overlap
            best = other_chrom
    return best, best_overlap


def write_mapping(path: Path, source_map, target_map):
    with path.open("w") as out:
        out.write("source_chrom\ttarget_chrom\toverlap\tsource_count\ttarget_count\tfrac_source\tfrac_target\n")
        for chrom in sorted(source_map.keys()):
            ids = source_map[chrom]
            target, overlap = best_match(ids, target_map)
            if target is None:
                out.write(f"{chrom}\t\t0\t{len(ids)}\t0\t0\t0\n")
                continue
            target_ids = target_map[target]
            frac_source = overlap / len(ids) if ids else 0
            frac_target = overlap / len(target_ids) if target_ids else 0
            out.write(
                f"{chrom}\t{target}\t{overlap}\t{len(ids)}\t{len(target_ids)}\t"
                f"{frac_source:.6f}\t{frac_target:.6f}\n"
            )


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare chrom files by protein ID overlap.")
    parser.add_argument("--new", required=True, help="New chrom file")
    parser.add_argument("--old", required=True, help="Old chrom file")
    parser.add_argument("--tag", required=True, help="Tag prefix for outputs")
    parser.add_argument("--outdir", default=".", help="Output directory")
    args = parser.parse_args()

    new_path = Path(args.new)
    old_path = Path(args.old)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    new_map, new_ids = read_chrom(new_path)
    old_map, old_ids = read_chrom(old_path)
    inter = new_ids & old_ids

    summary_path = outdir / f"{args.tag}_summary.txt"
    with summary_path.open("w") as out:
        out.write(f"new_file\t{new_path}\n")
        out.write(f"old_file\t{old_path}\n")
        out.write(f"new_proteins\t{len(new_ids)}\n")
        out.write(f"old_proteins\t{len(old_ids)}\n")
        out.write(f"intersection\t{len(inter)}\n")
        out.write(f"intersection_frac_new\t{(len(inter)/len(new_ids)) if new_ids else 0:.6f}\n")
        out.write(f"intersection_frac_old\t{(len(inter)/len(old_ids)) if old_ids else 0:.6f}\n")

    write_mapping(outdir / f"{args.tag}_new_to_old.tsv", new_map, old_map)
    write_mapping(outdir / f"{args.tag}_old_to_new.tsv", old_map, new_map)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
