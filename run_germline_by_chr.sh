#!/bin/bash
# Run GERMLINE per-chromosome to avoid segfaults on large chromosomes.
# Usage: bash run_germline_by_chr.sh

PED="germline_input.ped"
MAP="germline_input_cm.map"
GERMLINE="./germline-1-5-3/bin/germline"
OUTDIR="germline_chr_results"
FINAL_OUTPUT="germline_full_out_cm.match"
MIN_M=3
BITS=64

mkdir -p "$OUTDIR"

# Get list of chromosomes from the map file
CHROMS=$(awk '{print $1}' "$MAP" | sort -un)
echo "Chromosomes found: $CHROMS"

# Split map file by chromosome
echo "=== Splitting map file by chromosome ==="
for CHR in $CHROMS; do
    awk -v c="$CHR" '$1 == c' "$MAP" > "$OUTDIR/chr${CHR}.map"
    N=$(wc -l < "$OUTDIR/chr${CHR}.map")
    echo "  chr$CHR: $N SNPs"
done

# Split PED file by chromosome
echo ""
echo "=== Splitting PED file by chromosome ==="

python3 << 'PYEOF'
import sys

map_file = "germline_input_cm.map"
ped_file = "germline_input.ped"
outdir = "germline_chr_results"

# Read map to get SNP indices per chromosome
chr_indices = {}
with open(map_file) as f:
    for i, line in enumerate(f):
        chrom = line.split()[0]
        if chrom not in chr_indices:
            chr_indices[chrom] = []
        chr_indices[chrom].append(i)

print("Total SNPs: %d" % sum(len(v) for v in chr_indices.values()))

# Read PED and split by chromosome
with open(ped_file) as f:
    ped_lines = f.readlines()

print("Total individuals: %d" % len(ped_lines))

for chrom, indices in sorted(chr_indices.items(), key=lambda x: int(x[0])):
    outpath = "%s/chr%s.ped" % (outdir, chrom)
    with open(outpath, 'w') as fout:
        for ped_line in ped_lines:
            parts = ped_line.strip().split()
            header = parts[:6]
            geno = parts[6:]

            selected = []
            for idx in indices:
                selected.append(geno[2*idx])
                selected.append(geno[2*idx + 1])

            fout.write(' '.join(header + selected) + '\n')

    print("  chr%s: %d SNPs -> %s" % (chrom, len(indices), outpath))

PYEOF

# Run GERMLINE per chromosome
echo ""
echo "=== Running GERMLINE per chromosome ==="
: > "$FINAL_OUTPUT"

for CHR in $CHROMS; do
    CHR_MAP="$OUTDIR/chr${CHR}.map"
    CHR_PED="$OUTDIR/chr${CHR}.ped"
    CHR_OUT="$OUTDIR/germline_chr${CHR}"

    echo "  chr$CHR: processing..."

    timeout 600 "$GERMLINE" \
        -input "$CHR_PED" "$CHR_MAP" \
        -output "$CHR_OUT" \
        -min_m "$MIN_M" -bits "$BITS" > /dev/null 2>&1
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ] && [ -f "${CHR_OUT}.match" ]; then
        NSEGS=$(wc -l < "${CHR_OUT}.match")
        echo "    -> $NSEGS segments found"
        cat "${CHR_OUT}.match" >> "$FINAL_OUTPUT"
    else
        echo "    -> FAILED (exit code $EXIT_CODE), skipping"
    fi
done

TOTAL=$(wc -l < "$FINAL_OUTPUT")
echo ""
echo "=== Done ==="
echo "Total segments: $TOTAL"
echo "Output: $FINAL_OUTPUT"
