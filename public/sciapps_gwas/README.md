# sciapps_gwas_conda — GWAS Pipeline for Sorghum

A Nextflow DSL2 pipeline that performs genome-wide association studies using TASSEL 5 (MLM) and EMMAX, running via a shared conda environment on SLURM.

## Pipeline Steps

| Step | Process | Description | Resource Label |
|------|---------|-------------|----------------|
| 1 | `preprocess_vcf` | Detect input format (VCF / HapMap), convert to IUPAC-coded HapMap | `medium` |
| 2 | `preprocess_trait` | Extract phenotype columns from trait file | `light` |
| 3 | `mergeg2p` | Intersect genotype and phenotype by common accessions | `light` |
| 4 | `npute` | Impute missing SNPs using NPUTE | `medium` |
| 5 | `numericaltransform` | Convert marker data to numerical format via TASSEL + PLINK | `medium` |
| 6 | `pca` | Principal component analysis with R prcomp | `light` |
| 7 | `mlm` | Mixed Linear Model with TASSEL 5 (with PCA covariates) | `medium` |
| 8 | `emmax` | Efficient Mixed-Model Association eXpedited | `medium` |

Steps 5–6 run in parallel after step 4; steps 7–8 run in parallel after steps 5–6.

## Requirements

- sciapps_gwas codebase `/grid/ware/data_norepl/luj/project/sorghum/nextflow/sciapps_gwas`
- [Nextflow](https://www.nextflow.io/) (DSL2)
- SLURM cluster (partition `cpuq`, QoS `cpuq_base`)
- Conda environment at `/grid/ware/data_norepl/luj/conda/sciapps_gwas`

## Usage

```bash
nextflow run main.nf \
  --marker_files <file_list> \
  --trait <phenotype_file> \
  [--trait_key_column <col>] \
  [--trait_value_columns <col1,col2,...>] \
  [--trait_header_lines <n>] \
  [--outdir <dir>] \
  [-resume] [-bg]
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--marker_files` | (required) | Path to a text file listing VCF/HapMap file paths (one per line) |
| `--trait` | (required) | Path to the phenotype/trait file |
| `--trait_key_column` | (auto-detected) | Column name in trait file containing accession IDs |
| `--trait_value_columns` | (all numeric columns) | Comma-separated trait column names to analyze |
| `--trait_header_lines` | `1` | Number of header lines in the trait file |
| `--outdir` | `results` | Output directory |
| `--partition` | `cpuq` | SLURM partition |
| `--qos` | `cpuq_base` | SLURM QoS |

## Input Formats

### Marker files

The pipeline auto-detects three formats:

- **VCF** – Standard Variant Call Format (`.vcf` / `.vcf.gz`)
- **HapMap (regular)** – Diploid genotypes (e.g. `AA`, `CT`)
- **HapMap (IUPAC)** – One-letter IUPAC codes (e.g. `A`, `R`, `Y`)

Pass a text file listing the input files (one per line):

```
test_data/chr8.vcf.gz
test_data/chr9.vcf.gz
```

All files are converted to IUPAC-coded HapMap internally.

### Phenotype file

Two formats are supported:

**Simple (1 header line):**
```
<Trait>	Trait1
PI656017	0.746
PI656030	-0.704
```

**Multi-column with key column (2+ header lines):**
```
SL	FULL_NEW_Publ	FloweringTime_T	PlantHeight_T
	PhenotypeClass	Reproductive	Vegetative
1	PI152651	-4.6007	19.1632
2	PI17548	-4.7259	84.0842
```

When a key column and value columns are specified, the pipeline extracts each trait into its own file and analyzes them independently.

## Outputs

All outputs go to `${outdir}` (default `results/`):

| File Pattern | Description |
|-------------|-------------|
| `mm_*.gz` | Merged marker × trait intersection |
| `npt_*.gz` | Imputed marker data |
| `nt1_marker.txt.gz` | Numerically transformed markers |
| `nt2mlmm.txt.gz` | MLMM-formatted marker matrix (CSV) |
| `nt3_*.tfam` / `nt4_*.tped.gz` | PLINK-formatted files for EMMAX |
| `pca_*.txt` | PCA covariates (TASSEL format) |
| `scree_*.png` | Scree plot |
| `pcplot_*.png` | PCA pairwise plot |
| `mlm1-4.txt` | TASSEL MLM results |
| `emmax_*.reml` | EMMAX REML estimates |
| `pval_emmax_*.ps` | EMMAX p-values |
| `manhattan_*.plot` / `*.view.tgz` | Manhattan plot data |
| `reports/` | Nextflow timeline, report, trace, DAG |

## Examples

### 1. Simple trait file, single trait column (auto-detect columns)

```bash
nextflow run main.nf \
  --marker_files test_data/vcf_list.txt \
  --trait test_data/trait.txt
```

### 2. Multi-column trait file with specific key and value columns

```bash
nextflow run main.nf \
  --marker_files test_data/vcf_list.txt \
  --trait test_data/SAP_TEST_Phenotype_Data.txt \
  --trait_key_column FULL_NEW_Publ \
  --trait_value_columns FloweringTime_T,PlantHeight_T \
  --trait_header_lines 2
```

### 3. Resume a previous run

```bash
nextflow run main.nf ... -resume
```

### 4. Run in background

```bash
nextflow run main.nf ... -bg 1 >| run.log 2>&1
```

## Resource Requirements

| Label | CPUs | Memory | Wall Time |
|-------|------|--------|-----------|
| `light` | 2 | 4 GB | 2 h |
| `medium` | 8 | 32 GB | 12 h |
| `heavy` | 32 | 128 GB | 48 h |
| `long` | 8 | 32 GB | 48 h |
