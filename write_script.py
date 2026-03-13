"""Write the GERMLINE per-chromosome runner script to WSL.

This version uses the original germline_input.map (no genetic distances).
It splits PED+MAP by chromosome, runs GERMLINE on each, and merges results.
"""
import os
import sys

# Choose map file: "cm" for genetic distances, "original" for the default map
mode = sys.argv[1] if len(sys.argv) > 1 else "cm"

if mode == "cm":
    MAP_FILE = "germline_input_cm.map"
    OUTPUT = "germline_full_out_cm.match"
    SPLIT_DIR = "germline_chr_results"
else:
    MAP_FILE = "germline_input.map"
    OUTPUT = "germline_full_out.match"
    SPLIT_DIR = "germline_chr_results_orig"

SCRIPT = r"""#!/bin/bash
set -o pipefail
cd /home/jpiepkorn/cse284-genomics-final-project

MAP_FILE="{map_file}"
PED_FILE="germline_input.ped"
OUTDIR="{split_dir}"
FINAL_OUTPUT="{output}"

mkdir -p "$OUTDIR"

# === Split map by chromosome ===
echo "Splitting map file: $MAP_FILE"
for CHR in $(cut -f1 "$MAP_FILE" | sort -un); do
  awk -v c="$CHR" '$1 == c' "$MAP_FILE" > "$OUTDIR/chr$CHR.map"
done
echo "Map split done"

# === Split PED by chromosome ===
echo "Splitting PED file..."
python3 - "$MAP_FILE" "$PED_FILE" "$OUTDIR" << 'PYEOF'
import sys
map_file, ped_file, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
chr_indices = {{}}
with open(map_file) as f:
    for i, line in enumerate(f):
        c = line.split()[0]
        chr_indices.setdefault(c, []).append(i)
with open(ped_file) as f:
    ped_lines = f.readlines()
for c in sorted(chr_indices, key=int):
    indices = chr_indices[c]
    with open(f"{{outdir}}/chr{{c}}.ped", 'w') as fout:
        for pl in ped_lines:
            parts = pl.strip().split()
            hdr = parts[:6]
            geno = parts[6:]
            sel = []
            for idx in indices:
                sel.append(geno[2*idx])
                sel.append(geno[2*idx+1])
            fout.write(' '.join(hdr + sel) + '\n')
    print(f"  chr{{c}}: {{len(indices)}} SNPs")
PYEOF
echo "PED split done"

# === Run GERMLINE per chromosome ===
echo ""
echo "=== Running GERMLINE per chromosome ==="
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
cp "$FINAL_OUTPUT" "/mnt/c/Users/jpiepkorn/cse284-genomics-final-project/$FINAL_OUTPUT"
echo "Copied to Windows"
""".format(map_file=MAP_FILE, output=OUTPUT, split_dir=SPLIT_DIR)

wsl_path = r"\\wsl$\Ubuntu\home\jpiepkorn\cse284-genomics-final-project\run_chr.sh"
with open(wsl_path, "w", newline="\n") as f:
    f.write(SCRIPT)
print("Script written for mode=%s (map=%s, output=%s)" % (mode, MAP_FILE, OUTPUT))
