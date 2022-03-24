# nf-core/quantms: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] nfcore/quantms - [18/03/2022] - Havana

Initial release of nf-core/quantms, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- New pipeline for DDA-LFQ data analysis
- New pipeline for DDA-ISO data analysis
- New datasets for DDA-LFQ and DDA-ISO data analsysis
- Documentation added for DDA pipeline
- First pipeline for DIA-LFQ data analsysis

### `Fixed`

- This is the first release - no reported issues

### `Dependencies`

The pipeline is using Nextflow DSL2, each process will be run with its own [Biocontainer](https://biocontainers.pro/#/registry). This means that on occasion it is entirely possible for the pipeline to be using different versions of the same tool. However, the overall software dependency changes compared to the last release have been listed below for reference.

| Dependency       | Version    |
| ---------------- | ---------- |
| `comet`          | 2021010    |
| `msgf+`          | 2022.01.07 |
| `openms`         | 2.8.0      |
| `sdrf-pipelines` | 0.0.21     |
| `percolator`     | 3.5        |
| `pmultiqc`       | 0.0.10     |
| `luciphor`       | 2020_04_03 |
| `dia-nn`         | 1.8        |

### `Deprecated`
