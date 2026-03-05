# CSE 284 Final Project

Our project is comparing the runtime and memory usage of PLINK versus GERMLINE. To evaluate these results, we are comparing the degree of relatedness between the pairs of genotypes outputted by each method. This comparison is between the pi_hat metric from PLINK and total shared IBD length between pairs from GERMLINE.

## Install Instructions 

```
conda create -n bio_bench python=3.9 -y
conda activate bio_bench 
conda install -c bioconda plink -y
conda install -c bioconda bcftools -y
conda install -c bioconda vcftools -y
conda install -c conda-forge pandas matplotlib seaborn -y
```

## Basic Usage
### PLINK
`plink --bfile ./data/toy_plink --genome --out plink_ibd`

### GERMLINE
`./germline-1-5-3/germline \
 -input ./data/toy_germline.ped ./data/toy_germline.map \
 -output germline_output \
 -min_m 2`

## Results

## Contributors

This repository was created by Jackie Piepkorn, Hannah Coates, and Jenny Mar for our CSE 284 Final Project.


