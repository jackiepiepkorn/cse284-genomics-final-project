# CSE 284 Final Project

Our project is comparing the runtime and memory usage of PLINK versus GERMLINE. To evaluate these results, we are comparing the degree of relatedness between the pairs of genotypes outputted by each method. This comparison is between the pi_hat metric from PLINK and total shared IBD length between pairs from GERMLINE.

### Windows Users Only:
You will need to run this tutorial in WSL. Download WSL in the terminal and install conda with these commands:
```
wsl --install
wget https://repo.anaconda.com/archive/Anaconda3-2025.12.2-Linux-x86_64.sh
bash Anaconda3-5.2.0-Linux-x86_64.sh
source ~/anaconda3/bin/activate
sudo apt install default-jre
```
You may need to run this command if you get a `bunzip2: command not found` error
```
sudo apt update
sudo apt install bzip2
```

## Install Instructions

```
conda create -n bio_bench python=3.9 -y
conda activate bio_bench 
conda install -c bioconda plink -y
conda install -c bioconda bcftools -y
conda install -c bioconda vcftools -y
conda install -c conda-forge pandas matplotlib seaborn -y
```
If you are in WSL, you may need to activate the conda environment by:
```
/home/*user*/anaconda3/envs/bio_bench
```

## Clone this repository
Run the following command to clone this repository and move into the directory:
```
git clone https://github.com/jackiepiepkorn/cse284-genomics-final-project.git
cd cse284-genomics-final-project
```

## Run PLINK
```
plink --bfile ./data/ps2_ibd.lwk --genome --out plink_ibd
```

## Convert Given Files to GERMLINE format
First convert to VCF:
```
plink --bfile ./data/ps2_ibd.lwk --recode vcf --out ps2_ibd.lwk
```
This will result in a ps2_ibd.lwk.vcf file that we can use to phase the data as required for GERMLINE processing.


We then use beagle 5.5 to phase the project. Run the below command:
```
java -jar beagle.27Feb25.75f.jar gt=ps2_ibd.lwk.vcf out=dataset_phased
```
This results in the creation of the dataset_phased.vcf.gz file which can then be used for creating the .ped and .map files.

```
plink --vcf dataset_phased.vcf.gz --biallelic-only strict --geno 0 --snps-only just-acgt --keep-allele-order --recode ped --out germline_input
```
This will output both a germline_input.map file and germline_input.ped file required to run germline.

Run Germline:
```
./germline-1-5-3/bin/germline -input germline_input.ped germline_input.map -output germline_full_out -min_m 3
```

## Results
We have successfully run the PLINK and GERMLINE commands to get the results. This includes the plink genome file and the germline match file. Now that we have compiled these result files we need to work on comparing the 2 metrics. In order to do this we will be working on a python script to extract the data from the 2 files and compare them across a similar ibd metric. This script is still in progress of being made so does not function properly yet.

## Next Steps
Our next steps are to finalize the comparison script compare_results to see where they vary as well as comparing runtime and memory usage. 

## Contributors

This repository was created by Jackie Piepkorn, Hannah Coates, and Jenny Mar for our CSE 284 Final Project.
