#!/bin/bash
set -o pipefail

MAP_FILE="germline_input_cm.map"
PED_FILE="germline_input.ped"
OUTDIR="germline_chr_results_orig"
FINAL_OUTPUT="germline_full_out.match"

mkdir -p "$OUTDIR"

echo "Splitting map file"
for CHR in $(cut -f1 "$MAP_FILE" | sort -un); do
  awk -v c="$CHR" '$1 == c' "$MAP_FILE" > "$OUTDIR/chr$CHR.map"
done
echo "Map split done"

echo "Splitting PED file"
python3 - "$MAP_FILE" "$PED_FILE" "$OUTDIR" << 'PYEOF'
import sys
map_file, ped_file, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
chr_indices = {}
with open(map_file) as f:
    for i, line in enumerate(f):
        c = line.split()[0]
        chr_indices.setdefault(c, []).append(i)
with open(ped_file) as f:
    ped_lines = f.readlines()
for c in sorted(chr_indices, key=int):
    indices = chr_indices[c]
    with open(f"{outdir}/chr{c}.ped", 'w') as fout:
        for pl in ped_lines:
            parts = pl.strip().split()
            hdr = parts[:6]
            geno = parts[6:]
            sel = []
            for idx in indices:
                sel.append(geno[2*idx])
                sel.append(geno[2*idx+1])
            fout.write(' '.join(hdr + sel) + '\n')
    print(f"  chr{c}: {len(indices)} SNPs")
PYEOF
echo "PED split done"

echo ""
echo "=== Run GERMLINE per chr ==="
> "$FINAL_OUTPUT"
for CHR in $(cut -f1 "$MAP_FILE" | sort -un); do
  echo "chr$CHR:"
  ./germline-1-5-3/bin/germline -input "$OUTDIR/chr$CHR.ped" "$OUTDIR/chr$CHR.map" -output "$OUTDIR/germline_chr$CHR" -min_m 3 -bits 64 > /dev/null 2>&1
  if [ -f "$OUTDIR/germline_chr$CHR.match" ]; then
    cat "$OUTDIR/germline_chr$CHR.match" >> "$FINAL_OUTPUT"
    wc -l < "$OUTDIR/germline_chr$CHR.match"
  else
    echo "FAILED"
  fi
done
echo "TOTAL:"
wc -l "$FINAL_OUTPUT"
