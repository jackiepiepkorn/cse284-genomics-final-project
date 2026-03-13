#!/usr/bin/env python3
"""
Split PED/MAP by chromosome and run GERMLINE on each separately.
Avoids segfaults that occur when running on all chromosomes at once.

Usage (from WSL):
    cd ~/cse284-genomics-final-project
    python3 run_germline_by_chr.py
"""

import os
import subprocess
import sys
from collections import defaultdict

# Configuration
PED_FILE = "germline_input.ped"
MAP_FILE = "germline_input_cm.map"
GERMLINE = "./germline-1-5-3/bin/germline"
OUTDIR = "germline_chr_results"
FINAL_OUTPUT = "germline_full_out_cm.match"
MIN_M = 3
BITS = 64
TIMEOUT = 600  # seconds per chromosome


def split_map(map_file, outdir):
    """Split map file by chromosome, return dict of chr -> (map_path, snp_indices)."""
    chr_data = defaultdict(list)
    chr_lines = defaultdict(list)

    with open(map_file) as f:
        for i, line in enumerate(f):
            chrom = line.split()[0]
            chr_data[chrom].append(i)
            chr_lines[chrom].append(line)

    for chrom in sorted(chr_data.keys(), key=int):
        map_path = os.path.join(outdir, "chr%s.map" % chrom)
        with open(map_path, 'w') as fout:
            fout.writelines(chr_lines[chrom])
        print("  chr%s: %d SNPs" % (chrom, len(chr_data[chrom])))

    return chr_data


def split_ped(ped_file, chr_data, outdir):
    """Split PED file by chromosome."""
    with open(ped_file) as f:
        ped_lines = f.readlines()

    print("  %d individuals" % len(ped_lines))

    for chrom in sorted(chr_data.keys(), key=int):
        indices = chr_data[chrom]
        ped_path = os.path.join(outdir, "chr%s.ped" % chrom)

        with open(ped_path, 'w') as fout:
            for ped_line in ped_lines:
                parts = ped_line.strip().split()
                header = parts[:6]
                geno = parts[6:]

                selected = []
                for idx in indices:
                    selected.append(geno[2 * idx])
                    selected.append(geno[2 * idx + 1])

                fout.write(' '.join(header + selected) + '\n')

        print("  chr%s PED written" % chrom)


def run_germline_per_chr(chr_data, outdir, final_output):
    """Run GERMLINE on each chromosome."""
    # Clear final output
    open(final_output, 'w').close()

    total_segs = 0
    completed = 0
    failed = 0

    for chrom in sorted(chr_data.keys(), key=int):
        chr_map = os.path.join(outdir, "chr%s.map" % chrom)
        chr_ped = os.path.join(outdir, "chr%s.ped" % chrom)
        chr_out = os.path.join(outdir, "germline_chr%s" % chrom)

        print("  chr%s: " % chrom, end="", flush=True)

        cmd = [
            GERMLINE,
            "-input", chr_ped, chr_map,
            "-output", chr_out,
            "-min_m", str(MIN_M),
            "-bits", str(BITS),
        ]

        try:
            result = subprocess.run(
                cmd,
                timeout=TIMEOUT,
                capture_output=True,
                text=True,
            )

            match_file = chr_out + ".match"
            if result.returncode == 0 and os.path.exists(match_file):
                nsegs = sum(1 for _ in open(match_file))
                print("%d segments" % nsegs)
                total_segs += nsegs
                completed += 1

                # Append to final output
                with open(final_output, 'a') as fout:
                    with open(match_file) as fin:
                        fout.write(fin.read())
            else:
                print("FAILED (exit code %d)" % result.returncode)
                if result.stderr:
                    print("    stderr: %s" % result.stderr[:200])
                failed += 1

        except subprocess.TimeoutExpired:
            print("TIMEOUT (>%ds)" % TIMEOUT)
            failed += 1
        except Exception as e:
            print("ERROR: %s" % str(e))
            failed += 1

    return total_segs, completed, failed


def main():
    os.makedirs(OUTDIR, exist_ok=True)

    print("=== Splitting map file ===")
    chr_data = split_map(MAP_FILE, OUTDIR)

    print("\n=== Splitting PED file ===")
    split_ped(PED_FILE, chr_data, OUTDIR)

    print("\n=== Running GERMLINE per chromosome ===")
    total_segs, completed, failed = run_germline_per_chr(chr_data, OUTDIR, FINAL_OUTPUT)

    print("\n=== Done ===")
    print("Chromosomes completed: %d" % completed)
    print("Chromosomes failed: %d" % failed)
    print("Total segments: %d" % total_segs)
    print("Output: %s" % FINAL_OUTPUT)

    # Copy to Windows side
    win_path = "/mnt/c/Users/jpiepkorn/cse284-genomics-final-project/" + FINAL_OUTPUT
    if os.path.exists(FINAL_OUTPUT):
        subprocess.run(["cp", FINAL_OUTPUT, win_path])
        print("Copied to: %s" % win_path)


if __name__ == "__main__":
    main()
