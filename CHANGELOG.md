# nf-core/quantms: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] nfcore/quantms

### `Added`

- [#386](https://github.com/bigbio/quantms/pull/386) Make validation of ontology terms optional

### Fixed
- [#400](https://github.com/bigbio/quantms/pull/400) The random file selection when using `random_preanalysis` with DIANN is now reproducible.

### `Changed`

### `Fixed`

- [#396](https://github.com/bigbio/quantms/pull/396) Added verification of tar archive unpacking to prevent silent failures.

### `Dependencies`

### `Parameters`

- `validate_ontologies`: enable or disable validating ontologies in the input SDRF file.

## [1.3.0] nfcore/quantms - [08/04/2024] - Santiago de Cuba

### `Added`

- [#335](https://github.com/bigbio/quantms/pull/335) (Performance improvement) Improvements in DIA pipeline to use random/subset files for library search
- [#351](https://github.com/bigbio/quantms/pull/351) Identification workflow for DDA data

### `Changed`

- [#365](https://github.com/bigbio/quantms/pull/365) Updated sdrf-pipelines==0.0.26
- [#359](https://github.com/bigbio/quantms/pull/359) Updated pmultiqc==0.0.25

### `Fixed`

- [#357](https://github.com/bigbio/quantms/pull/357) Chymotrypsin -> Chymotrypsin/P in MSGF+
- [#355](https://github.com/bigbio/quantms/pull/355) Fixes bin/diann_convert.py
- [#316](https://github.com/bigbio/quantms/pull/316) Fixing MSGF+ error

### `Dependencies`

### `Parameters`

- id_only: Only perform identification, no quantification
- min_peaks: Minimum number of peaks in a spectrum to be considered for search
- export_decoy_psm: Export decoy PSMs
- skip_rescoring: Skip rescoring
- skip_preliminary_analysis: Skip preliminary analysis in DIA-NN
- empirical_assembly_log: Path to the empirical assembly log file
- random_preanalysis: Use random/subset files for library search
- empirical_assembly_ms_n: Number of MS runs to use for empirical assembly

### `Deprecations`

## [1.2.0] nfcore/quantms - [11/02/2023] - Thimphu

### `Added`

- [#275 BigBio](https://github.com/bigbio/quantms/pull/275) Added support for bruker data in DIA branch.
- [#275 BigBio](https://github.com/bigbio/quantms/pull/275) And speed-up to DIA-NN pipeline.
- [#275 BigBio](https://github.com/bigbio/quantms/pull/275) Support for library-base search in DIA-NN pipeline.
- [#300 BigBio](https://github.com/bigbio/quantms/pull/300) Major refactoring of LFQ-DDA MBR algorithm.
- [#279 BigBio](https://github.com/bigbio/quantms/pull/279) Support for SAGE search engine.

### `Changed`

- [#314](https://github.com/bigbio/quantms/pull/314) Update for pmultiqc to pmultiqc=0.0.23
- [#308](https://github.com/bigbio/quantms/pull/308) Update for openms to openms=3.1.0
- Update for sdrf-pipelines to sdrf-pipelines=0.0.24
- Update for msstats to msstats=4.2.1

### `Fixed`

- [#316](https://github.com/bigbio/quantms/pull/316) Fixed jar path selection of luciphoradapter and msgf+
- Fixed bug where modification masses were not calculated correctly in DIA-NN conversion.
- Fixed multiple bugs Pull Request [#293 BigBio](https://github.com/bigbio/quantms/pull/293), [#279 BigBio](https://github.com/bigbio/quantms/pull/279), [#265 BigBio](https://github.com/bigbio/quantms/pull/265), [#260 BigBio](https://github.com/bigbio/quantms/pull/260), [#257 BigBio](https://github.com/bigbio/quantms/pull/257)

### `Dependencies`

- New dependency on `sage` search engine.

### `Parameters`

- feature_with_id_min_score: Minimum score of a feature with a peptide identification (default: 0.10)
- feature_without_id_min_score: Minimum score of a feature without peptide identification (transfer feature, default: 0.75)
- lfq_intensity_threshold: Minimum intensity of a feature to be considered in the MBR algorithm (default: 1000)
- sage_processes: Number of processes to use in SAGE search engine (default: 1)
- diann_speclib: Path to the spectral library to use in DIA-NN (default: null)
- convert_dotd: if convert .d file to mzml (default: false)

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
| `openms`              | 3.1.0      |
| `sdrf-pipelines`      | 0.0.26     |
| `percolator`          | 3.5        |
| `pmultiqc`            | 0.0.24     |
| `luciphor`            | 2020_04_03 |
| `dia-nn`              | 1.8.1      |
| `msstats`             | 4.10.0     |
| `msstatstmt`          | 2.10.0     |
