# quantms

[![GitHub release](https://img.shields.io/github/v/release/bigbio/quantms)](https://github.com/bigbio/quantms/releases)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A523.04.0-brightgreen.svg)](https://www.nextflow.io/)
[![CI](https://github.com/bigbio/quantms/actions/workflows/ci.yml/badge.svg)](https://github.com/bigbio/quantms/actions/workflows/ci.yml)

**Cloud-ready Nextflow pipeline for DDA quantitative proteomics.**

![quantms workflow](images/quantms_metro.png)

quantms orchestrates end-to-end proteomics analysis — from raw mass spectrometry data to protein quantification, quality control, and differential expression. It supports DDA label-free (LFQ) and isobaric labeling (TMT/iTRAQ) workflows.

> **DIA users:** DIA proteomics is handled by the dedicated [quantmsdiann](https://quantmsdiann.quantms.org) pipeline.

## Key Features

- **Two DDA workflows**: LFQ and TMT/iTRAQ (isobaric labeling) in a single pipeline
- **ML-powered rescoring**: MS2PIP, DeepLC, and Percolator boost identification rates by 10-30%
- **Cloud-ready**: Runs on AWS, GCP, Azure, HPC clusters, or your laptop via Nextflow
- **Standardized metadata**: SDRF-driven experiment annotation ensures reproducibility
- **Quality control**: Integrated pmultiqc reports with interactive HTML dashboards
- **Ecosystem integration**: Output compatible with mokume, qpx, and the quantms data portal

## Quick Start

```bash
# Install Nextflow
curl -s https://get.nextflow.io | bash

# Run the test profile
nextflow run bigbio/quantms \
    -profile test,docker \
    --outdir results/

# Run with your data
nextflow run bigbio/quantms \
    -profile docker \
    --input samplesheet.csv \
    --database uniprot_human.fasta \
    --outdir results/
```

## Workflows

| Workflow | Flag | Description |
|----------|------|-------------|
| **DDA-LFQ** | `--workflow lfq` | Label-free quantification using OpenMS + search engines |
| **DDA-ISO** | `--workflow iso` | Isobaric labeling (TMT, iTRAQ) with channel-level quantification |

See [Workflows](workflows.md) for detailed descriptions.

## Citation

> Dai C, Pfeuffer J, Wang H, et al. **quantms: a cloud-based pipeline for quantitative proteomics enables the reanalysis of public proteomics data.** *Nature Methods.* 2024;21:1603-1607. [DOI: 10.1038/s41592-024-02343-1](https://doi.org/10.1038/s41592-024-02343-1)

## Ecosystem

| Tool | Description |
|------|-------------|
| [quantmsdiann](https://github.com/bigbio/quantmsdiann) | DIA proteomics pipeline powered by DIA-NN |
| [mokume](https://mokume.quantms.org) | Protein quantification library (successor to ibaqpy) |
| [qpx](https://qpx.quantms.org) | Data format conversion and QPX format tools |
| [pmultiqc](https://pmultiqc.quantms.org) | Interactive QC reporting for proteomics |
| [portal.quantms.org](https://portal.quantms.org) | Browse reanalyzed proteomics datasets |
