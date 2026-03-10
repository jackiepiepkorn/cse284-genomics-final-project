#!/bin/bash
# ============================================================
# benchmark.sh — Runtime & Memory Benchmark: PLINK vs GERMLINE
# ============================================================
# Usage (run from WSL inside the project directory):
#   conda activate bio_bench
#   bash benchmark.sh
#
# Requires: /usr/bin/time (GNU time, not shell builtin)
#   Install if missing:  sudo apt install time
#
# Output: benchmark_results.csv  (consumed by the notebook)
# ============================================================

set -euo pipefail

INPUT_BED="./data/ps2_ibd.lwk"
GERMLINE_BIN="./germline-1-5-3/bin/germline"
GERMLINE_PED="germline_input.ped"
GERMLINE_MAP="germline_input.map"
OUTFILE="benchmark_results.csv"
NUM_RUNS=3

# Check prerequisites
if ! command -v plink &>/dev/null; then
    echo "ERROR: plink not found. Activate bio_bench conda environment first."
    exit 1
fi
if ! command -v /usr/bin/time &>/dev/null; then
    echo "ERROR: GNU time not found. Install with: sudo apt install time"
    exit 1
fi

# ---- helper: run a command and extract time/memory from GNU time ----
# Appends one row per run to $OUTFILE
run_benchmark() {
    local label="$1"
    shift
    local timefile
    timefile=$(mktemp)

    /usr/bin/time -v "$@" 2>"$timefile" || true

    wall=$(grep "Elapsed (wall clock)" "$timefile" | sed 's/.*: //')
    user=$(grep "User time"            "$timefile" | head -1 | awk '{print $NF}')
    sys=$(grep "System time"           "$timefile" | head -1 | awk '{print $NF}')
    maxrss=$(grep "Maximum resident"   "$timefile" | awk '{print $NF}')   # in KB

    # Convert wall clock (h:mm:ss or m:ss.ss) to seconds
    wall_sec=$(echo "$wall" | awk -F: '{
        if (NF==3) print $1*3600 + $2*60 + $3;
        else if (NF==2) print $1*60 + $2;
        else print $1
    }')

    echo "$label,$i,$wall_sec,$user,$sys,$maxrss" >> "$OUTFILE"
    echo "    Wall: ${wall}  |  User: ${user}s  |  Sys: ${sys}s  |  MaxRSS: ${maxrss} KB"

    rm -f "$timefile"
}

# ---- initialise results file (one row per run) ----
echo "tool,run,wall_seconds,user_seconds,sys_seconds,max_rss_kb" > "$OUTFILE"

# ============================================================
# 1. PLINK IBD  (run NUM_RUNS times)
# ============================================================
for i in $(seq 1 $NUM_RUNS); do
    echo ">>> PLINK run $i/$NUM_RUNS ..."
    rm -f plink_bench_ibd.*
    run_benchmark "PLINK" plink --bfile "$INPUT_BED" --genome --out plink_bench_ibd
done

# ============================================================
# 2. GERMLINE IBD  (run NUM_RUNS times)
# ============================================================
# Check that the GERMLINE input files exist
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

rm -f germline_bench_out.*
for i in $(seq 1 $NUM_RUNS); do
    echo ">>> GERMLINE run $i/$NUM_RUNS ..."
    rm -f germline_bench_out.*
    run_benchmark "GERMLINE" "$GERMLINE_BIN" \
        -input "$GERMLINE_PED" "$GERMLINE_MAP" \
        -output germline_bench_out \
        -min_m 3
done

# ============================================================
# Done
# ============================================================
echo ""
echo "=== Benchmark Results ==="
column -t -s',' "$OUTFILE"
echo ""
echo "Results saved to $OUTFILE"
