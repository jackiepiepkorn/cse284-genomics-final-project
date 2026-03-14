#!/bin/bash

set -euo pipefail

INPUT_BED="./data/ps2_ibd.lwk"
GERMLINE_BIN="./germline-1-5-3/bin/germline"
GERMLINE_PED="germline_input.ped"
GERMLINE_MAP="germline_input_cm.map"
OUTFILE="benchmark_results.csv"
NUM_RUNS=3
BENCH_CHR_DIR="germline_bench_chr"
MIN_M=3
BITS=64

if ! command -v plink &>/dev/null; then
    echo "ERROR: plink not found. Activate bio_bench conda environment first."
    exit 1
fi
if ! command -v /usr/bin/time &>/dev/null; then
    echo "ERROR: GNU time not found. Install with: sudo apt install time"
    exit 1
fi

run_benchmark() {
    local label="$1"
    shift
    local timefile
    timefile=$(mktemp)

    /usr/bin/time -v "$@" 2>"$timefile" || true

    wall=$(grep "Elapsed (wall clock)" "$timefile" | sed 's/.*: //')
    user=$(grep "User time"            "$timefile" | head -1 | awk '{print $NF}')
    sys=$(grep "System time"           "$timefile" | head -1 | awk '{print $NF}')
    maxrss=$(grep "Maximum resident"   "$timefile" | awk '{print $NF}') 

    wall_sec=$(echo "$wall" | awk -F: '{
        if (NF==3) print $1*3600 + $2*60 + $3;
        else if (NF==2) print $1*60 + $2;
        else print $1
    }')

    echo "$label,$RUN_NUM,$wall_sec,$user,$sys,$maxrss" >> "$OUTFILE"
    echo "    Wall: ${wall}  |  User: ${user}s  |  Sys: ${sys}s  |  MaxRSS: ${maxrss} KB"

    rm -f "$timefile"
}

parse_time_file() {
    local timefile="$1"
    local wall user_t sys_t maxrss wall_sec

    wall=$(grep "Elapsed (wall clock)" "$timefile" | sed 's/.*: //')
    user_t=$(grep "User time"          "$timefile" | head -1 | awk '{print $NF}')
    sys_t=$(grep "System time"         "$timefile" | head -1 | awk '{print $NF}')
    maxrss=$(grep "Maximum resident"   "$timefile" | awk '{print $NF}')

    wall_sec=$(echo "$wall" | awk -F: '{
        if (NF==3) print $1*3600 + $2*60 + $3;
        else if (NF==2) print $1*60 + $2;
        else print $1
    }')

    echo "$wall_sec $user_t $sys_t $maxrss"
}

echo "tool,run,wall_seconds,user_seconds,sys_seconds,max_rss_kb" > "$OUTFILE"

for RUN_NUM in $(seq 1 $NUM_RUNS); do
    echo ">>> PLINK run $RUN_NUM/$NUM_RUNS ..."
    rm -f plink_bench_ibd.*
    run_benchmark "PLINK" plink --bfile "$INPUT_BED" --genome --out plink_bench_ibd
done

if [[ ! -f "$GERMLINE_PED" || ! -f "$GERMLINE_MAP" ]]; then
    echo ""
    echo "GERMLINE input files not found ($GERMLINE_PED / $GERMLINE_MAP)."
    echo "Generating them now (this does NOT count toward the benchmark)..."
    plink --bfile "$INPUT_BED" --recode vcf --out ps2_ibd.lwk 2>/dev/null
    if [[ ! -f beagle.27Feb25.75f.jar ]]; then
        echo "ERROR: beagle jar not found. Please download beagle first."
        echo "Skipping GERMLINE benchmark."
        echo "GERMLINE,NA,NA,NA,NA" >> "$OUTFILE"
        cat "$OUTFILE"
        exit 0
    fi
    java -jar beagle.27Feb25.75f.jar gt=ps2_ibd.lwk.vcf out=dataset_phased 2>/dev/null
    plink --vcf dataset_phased.vcf.gz --biallelic-only strict --geno 0 \
          --snps-only just-acgt --keep-allele-order --recode ped \
          --out germline_input 2>/dev/null
fi

mkdir -p "$BENCH_CHR_DIR"
CHROMS=$(cut -f1 "$GERMLINE_MAP" | sort -un)

for RUN_NUM in $(seq 1 $NUM_RUNS); do
    echo ""
    echo ">>> GERMLINE run $RUN_NUM/$NUM_RUNS ..."
    rm -f germline_bench_out.*
    run_benchmark "GERMLINE" "$GERMLINE_BIN" \
        -input "$GERMLINE_PED" "$GERMLINE_MAP" \
        -output germline_bench_out \
        -min_m "$MIN_M"
done

echo ""
echo "=== Splitting input files by chromosome (not timed) ==="
for CHR in $CHROMS; do
    awk -v c="$CHR" '$1 == c' "$GERMLINE_MAP" > "$BENCH_CHR_DIR/chr${CHR}.map"
done

python3 - "$GERMLINE_MAP" "$GERMLINE_PED" "$BENCH_CHR_DIR" << 'PYEOF'
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

echo "Split done."

for RUN_NUM in $(seq 1 $NUM_RUNS); do
    echo ""
    echo ">>> GERMLINE (per-chr) run $RUN_NUM/$NUM_RUNS ..."

    total_wall=0
    total_user=0
    total_sys=0
    peak_rss=0

    for CHR in $CHROMS; do
        timefile=$(mktemp)

        rm -f "$BENCH_CHR_DIR/germline_bench_chr${CHR}."*

        /usr/bin/time -v "$GERMLINE_BIN" \
            -input "$BENCH_CHR_DIR/chr${CHR}.ped" "$BENCH_CHR_DIR/chr${CHR}.map" \
            -output "$BENCH_CHR_DIR/germline_bench_chr${CHR}" \
            -min_m "$MIN_M" -bits "$BITS" > /dev/null 2>"$timefile" || true

        read -r w u s r <<< "$(parse_time_file "$timefile")"
        echo "    chr$CHR  wall=${w}s  user=${u}s  sys=${s}s  rss=${r}KB"

        total_wall=$(echo "$total_wall + $w" | bc)
        total_user=$(echo "$total_user + $u" | bc)
        total_sys=$(echo "$total_sys + $s" | bc)
        if [ "$(echo "$r > $peak_rss" | bc)" -eq 1 ]; then
            peak_rss=$
        fi

        rm -f "$timefile"
    done

    echo "GERMLINE_perchr,$RUN_NUM,$total_wall,$total_user,$total_sys,$peak_rss" >> "$OUTFILE"
    echo "  TOTAL  Wall: ${total_wall}s  |  User: ${total_user}s  |  Sys: ${total_sys}s  |  Peak RSS: ${peak_rss} KB"
done

echo ""
echo "=== Benchmark Results ==="
column -t -s',' "$OUTFILE"
echo ""
echo "Results saved to $OUTFILE"
