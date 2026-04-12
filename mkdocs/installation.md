# Installation

## Requirements

- [Nextflow](https://www.nextflow.io/) (>= 23.04.0)
- Container engine: [Docker](https://www.docker.com/), [Singularity](https://sylabs.io/singularity/), or [Conda](https://docs.conda.io/)

## Install Nextflow

```bash
# Install Nextflow
curl -s https://get.nextflow.io | bash

# Move to a directory in your PATH
mv nextflow ~/bin/

# Verify
nextflow -version
```

## Run the Test Profile

The fastest way to verify your setup:

```bash
# With Docker
nextflow run bigbio/quantms -profile test,docker --outdir test_results/

# With Singularity
nextflow run bigbio/quantms -profile test,singularity --outdir test_results/

# With Conda
nextflow run bigbio/quantms -profile test,conda --outdir test_results/
```

This downloads a small test dataset and runs the full pipeline. Should complete in ~10 minutes.

## Container Profiles

| Profile | Command | Notes |
|---------|---------|-------|
| `docker` | `-profile docker` | Recommended for local development |
| `singularity` | `-profile singularity` | Recommended for HPC clusters |
| `conda` | `-profile conda` | Slower setup, useful when containers unavailable |

## Cloud Execution

quantms runs on any cloud platform supported by Nextflow:

### AWS Batch

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input s3://bucket/samplesheet.csv \
    --database s3://bucket/uniprot.fasta \
    --outdir s3://bucket/results/ \
    -work-dir s3://bucket/work/
```

### Google Cloud Life Sciences

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input gs://bucket/samplesheet.csv \
    --outdir gs://bucket/results/ \
    -work-dir gs://bucket/work/
```

### Azure Batch

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input az://container/samplesheet.csv \
    --outdir az://container/results/ \
    -work-dir az://container/work/
```

### HPC (SLURM)

```bash
nextflow run bigbio/quantms \
    -profile singularity \
    --input samplesheet.csv \
    --outdir results/ \
    -queue your_partition
```

## Specific Versions

```bash
# Run a specific release
nextflow run bigbio/quantms -r v1.2.0 -profile docker --outdir results/

# Pull the latest version
nextflow pull bigbio/quantms
```

## Offline Mode

For environments without internet access:

```bash
# On a machine with internet: pull pipeline and containers
nextflow pull bigbio/quantms
nextflow run bigbio/quantms -profile singularity --outdir /dev/null

# Transfer the Nextflow cache and Singularity images to your offline machine
```
