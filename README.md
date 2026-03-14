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
conda install numpy
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

Interpolate the GERMLINE .map file:
```
wget https://bochet.gcc.biostat.washington.edu/beagle/genetic_maps/plink.GRCh37.map.zip
unzip plink.GRCh37.map.zip -d genetic_maps/

python interpolate_cm.py germline_input.map genetic_maps/ germline_input_cm.map
```

Run GERMLINE on each chromosome:
```
bash run_chr.sh
```
This should output a file named `germline_full_out.match`

## Running the Benchmarking Script
```
bash benchmark.sh
```
This should output a file named `benchmark_results.csv`

## Running the Compare Results Notebook
Run all the cells in the compare_results.ipynb notebook to compare the two commands. This will create figures on the output of the commands and their respective resource usage.

## Results
We analyzed the relatedness of genome pairs with PLINK and GERMLINE and compared their runtimes and memory usage. For comparing relative finding, we first parsed the match file containing the detected IBD segment matches, which was the output from running GERMLINE. We then merged overlapping segments per pair and chromosome, ensuring that any overlapping portions across the matches were not double counted. As some sections appeared across multiple matches. The segment lengths were then summed to compute total shared segments per pair. For PLINK postprocessing, we parsed the .genome output file and extracted PI_HAT, which represents pairwise relatedness. To compare these two output files, we merged the two dataframes on their pair_ids and graphed a scatter plot. We also calculated the Pearson correlation coefficient and p-value to further analyze the statistical significance of this comparison, using pearsonr from SciPy.stats.

In order to analyze the runtime and memory usage of PLINK versus GERMLINE, we created a benchmark script to run commands that extract time and memory from GNU time. For runtime, we evaluated based on wall clock time, user time, and system time. We evaluated based on the maximum resident set size for analyzing memory usage. We ran the runtime and memory commands three times and took the mean, in order to account for variance.

## Next Steps
One potential future direction is testing PLINK and GERMLINE on a different dataset that have varying demographic histories. It could be very interesting to test on populations with recent admixture or those with bottleneck events. This would help us analyze the strengths and weaknesses of each command on various types of data and allow us to see how it performs in different contexts. Another future direction is developing more documentation on comparing PLINK and GERMLINE. Because it would have been helpful to us to have more information on how to postprocess the GERMLINE output to compare the two, as well as how to use the commands on both Mac and Windows machines, we could develop documentation on this information.

## Contributors

This repository was created by Jackie Piepkorn, Hannah Coates, and Jenny Mar for our CSE 284 Final Project.
