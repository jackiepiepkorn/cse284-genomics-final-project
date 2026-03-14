#!/usr/bin/env python3
import sys
import os
import numpy as np
from collections import defaultdict


def load_genetic_map(map_dir):
    genetic_map = {}

    for chrom in range(1, 23):
        candidates = [
            os.path.join(map_dir, f"plink.chr{chrom}.GRCh37.map"),
            os.path.join(map_dir, f"chr{chrom}.map"),
            os.path.join(map_dir, f"genetic_map_chr{chrom}.txt"),
            os.path.join(map_dir, f"genetic_map_GRCh37_chr{chrom}.txt"),
        ]

        filepath = None
        for c in candidates:
            if os.path.exists(c):
                filepath = c
                break

        if filepath is None:
            continue

        positions = []
        cm_values = []

        with open(filepath) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split()
                if len(parts) >= 4:
                    try:
                        bp = int(parts[3])
                        cm = float(parts[2])
                        positions.append(bp)
                        cm_values.append(cm)
                    except (ValueError, IndexError):
                        try:
                            bp = int(parts[1])
                            cm = float(parts[3])
                            positions.append(bp)
                            cm_values.append(cm)
                        except (ValueError, IndexError):
                            continue
                elif len(parts) == 3:
                    try:
                        bp = int(parts[0])
                        cm = float(parts[2])
                        positions.append(bp)
                        cm_values.append(cm)
                    except (ValueError, IndexError):
                        continue

        if positions:
            order = np.argsort(positions)
            genetic_map[str(chrom)] = {
                "positions": np.array(positions)[order],
                "cm": np.array(cm_values)[order],
            }
            print(f"  chr{chrom}: {len(positions)} reference markers, "
                  f"range {positions[0]}-{positions[-1]} bp, "
                  f"0-{cm_values[-1]:.2f} cM")

    return genetic_map


def interpolate_cm(bp, ref_positions, ref_cm):
    if bp <= ref_positions[0]:
        return ref_cm[0]
    if bp >= ref_positions[-1]:
        return ref_cm[-1]
    return float(np.interp(bp, ref_positions, ref_cm))


def process_map_file(input_map, genetic_map, output_map):
    total = 0
    interpolated = 0
    missing_chr = 0

    with open(input_map) as fin, open(output_map, "w") as fout:
        for line in fin:
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            # Map format: chr  rsID  cM  bp
            chrom = parts[0]
            rsid = parts[1]
            bp = int(parts[3])
            total += 1

            if chrom in genetic_map:
                ref = genetic_map[chrom]
                cm = interpolate_cm(bp, ref["positions"], ref["cm"])
                interpolated += 1
            else:
                cm = 0.0
                missing_chr += 1

            fout.write(f"{chrom}\t{rsid}\t{cm:.6f}\t{bp}\n")

    print(f"\nDone! Processed {total} SNPs")
    print(f"  Interpolated: {interpolated}")
    print(f"  Missing chromosome in ref map: {missing_chr}")


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(1)

    input_map = sys.argv[1]
    map_dir = sys.argv[2]
    output_map = sys.argv[3]

    if not os.path.exists(input_map):
        print(f"ERROR: Input map file not found: {input_map}")
        sys.exit(1)

    if not os.path.isdir(map_dir):
        # Maybe it's a single file or prefix — check parent dir
        if os.path.isfile(map_dir):
            map_dir = os.path.dirname(map_dir)
        else:
            print(f"ERROR: Genetic map directory not found: {map_dir}")
            sys.exit(1)

    print(f"Input map:    {input_map}")
    print(f"Genetic maps: {map_dir}")
    print(f"Output map:   {output_map}")
    print()

    print("Loading reference genetic map...")
    genetic_map = load_genetic_map(map_dir)

    if not genetic_map:
        print("ERROR: No genetic map data loaded!")
        sys.exit(1)

    print(f"\nLoaded genetic maps for {len(genetic_map)} chromosomes")
    print("\nInterpolating cM values...")
    process_map_file(input_map, genetic_map, output_map)
    print("\nSanity check (first 5 lines of output):")
    with open(output_map) as f:
        for i, line in enumerate(f):
            if i >= 5:
                break
            print(f"  {line.strip()}")


if __name__ == "__main__":
    main()
