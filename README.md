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

## PLINK Data
Download the PLINK data from this repository under data folder

## GERMLINE Data
Download the GERMLINE data at these links 
lmk_germline_final.map: https://drive.google.com/file/d/1BA5XkhA280xpmWY1inhdJMVrMOoBeWKD/view?usp=sharing
lmk_germline_final.ped:
https://drive.google.com/file/d/1c-HMmaGCIprLfwWvbmbIlsU4--CwE3ey/view?usp=sharing

## Downloading and Running GERMLINE
1) Download GERMLINE from here: http://gusevlab.org/projects/germline/
2) Run this `tar -xvzf germline-1-5-3.tar.gz`
3) Move into GERMLINE directory and run `make` to test that it works

## Basic Usage
### PLINK
`plink --bfile ./data/toy_plink --genome --out plink_ibd`

### GERMLINE
`./germline-1-5-3/germline \
 -input ./data/toy_germline.ped ./data/toy_germline.map \
 -output germline_output \
 -min_m 2`

## Results
We were able to succesfully run PLINK and GERMLINE on the data. Our next step will be comparing runtime and memory usage.

## Contributors

This repository was created by Jackie Piepkorn, Hannah Coates, and Jenny Mar for our CSE 284 Final Project.


