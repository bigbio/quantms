# nf-core/quantms: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0dev] nfcore/quantms - [TBD] - Thimphu

### `Added`

- [#275 BigBio](https://github.com/bigbio/quantms/pull/275) Added support for bruker data. And speed-up to DIA-NN pipeline.

### `Changed`

### `Fixed`

- Fixed bug where modification masses were not calculated correctly in DIA-NN conversion.

### `Dependencies`

### `Parameters`

### `Deprecations`

## [1.1.1] nfcore/quantms - [03/27/23] - Berlin-Bern

### `Added`

- [#92](https://github.com/nf-core/quantms/pull/92) Improved output docs for mzTab
- [#91](https://github.com/nf-core/quantms/pull/91) Added dev profile for nightly versions of OpenMS tools

### `Changed`

- [#88](https://github.com/nf-core/quantms/pull/88) Updated Comet version to latest release (2023010)

### `Fixed`

- [#93](https://github.com/nf-core/quantms/pull/93) Fixed bug in docker vs. singularity container logic in some processes.

## [1.1.0] nfcore/quantms - [03/20/2023] - Berlin

- Bugfixes and speed increases in the OpenMS tools due to version update to 2.9.1
- Improvements in logging by adding many more process.ids
- Large restructuring of DIA branch to increase parallelizability
- Better error handling in MSstats step plus new parameter to filter for MSstats' adjusted p-value in the plots
- More efficient parsing of mzML statistics in a separate step
- A clearer distinction between per-run and experiment-wide FDRs with one parameter for each
- More test profiles including larger "full" tests

### `Added`

- [#176](https://github.com/bigbio/quantms/pull/176) - Add name of each ID step
- [#205](https://github.com/bigbio/quantms/pull/205) - mzTab export for DIANN outputs

### `Changed`

- [#169](https://github.com/bigbio/quantms/pull/169) - Restruct DIA-NN step1 : Generate an in silico predicted spectral library
- [#178](https://github.com/bigbio/quantms/pull/178) - Restruct DIA-NN step2 : Preliminary analysis of individual raw files
- [#179](https://github.com/bigbio/quantms/pull/179) - Restruct DIA-NN steps 3-5 to be as parallel as possible
- [#200](https://github.com/bigbio/quantms/pull/200) - Rename MSstats/Triqler/mzTab input and output

### `Fixed`

- [#187](https://github.com/bigbio/quantms/pull/187) - Bug fixing in proteomicsLFQ applying FDR at PSM level
- [#207](https://github.com/bigbio/quantms/pull/207) - Bug fixing in dissociation method translation for Luciphor

### `Dependencies`

- [#203](https://github.com/bigbio/quantms/pull/203) - update openms dependency -> 3.0.0dev
- [#208](https://github.com/bigbio/quantms/pull/208) - update pmultiqc dependency -> 0.0.13. Support for DIANN in pmultiqc and enable the generation of search engine scores distributions/peptide and protein table by pmultiqc.

### `Parameters`

- [#193](https://github.com/bigbio/quantms/pull/193) - Set the `local_input_type` default parameter to `mzML`
- [#212](https://github.com/bigbio/quantms/pull/212) - Set the `min_consensus_support` default parameter to `1` to filter in ConsensusID for peptides identified with both search engines
- [#200](https://github.com/bigbio/quantms/pull/200) - Add `export_mztab` parameter to allow to run PROTEINQUANTIFIER TMT without exporting to mzTab

## [1.0] nfcore/quantms - [05/02/2022] - Havana

Initial release of nf-core/quantms, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- New pipeline for DDA-LFQ data analysis
- New pipeline for DDA-ISO data analysis
- New datasets for DDA-LFQ and DDA-ISO data analysis
- Documentation added for DDA pipeline
- First pipeline for DIA-LFQ data analysis

### `Fixed`

- This is the first release - no reported issues

### `Dependencies`

The pipeline is using Nextflow DSL2, each process will be run with its own [Biocontainer](https://biocontainers.pro/#/registry). This means that on occasion it is entirely possible for the pipeline to be using different versions of the same tool. However, the overall software dependency changes compared to the last release have been listed below for reference.

| Dependency            | Version    |
| --------------------- | ---------- |
| `thermorawfileparser` | 1.3.4      |
| `comet`               | 2021010    |
| `msgf+`               | 2022.01.07 |
| `openms`              | 2.9.1      |
| `sdrf-pipelines`      | 0.0.22     |
| `percolator`          | 3.5        |
| `pmultiqc`            | 0.0.11     |
| `luciphor`            | 2020_04_03 |
| `dia-nn`              | 1.8.1      |
| `msstats`             | 4.2.0      |
| `msstatstmt`          | 2.2.0      |
