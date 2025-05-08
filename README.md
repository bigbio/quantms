# ![bigbio/quantms](docs/images/nf-core-quantms_logo_light.png#gh-light-mode-only) ![bigbio/quantms](docs/images/nf-core-quantms_logo_dark.png#gh-dark-mode-only)

[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/quantms/results)[![Cite with Zenodo](https://img.shields.io/badge/DOI-10.5281/zenodo.7754148-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.7754148)
[![GitHub Actions CI Status](https://github.com/bigbio/quantms/actions/workflows/ci.yml/badge.svg)](https://github.com/bigbio/quantms/actions/workflows/ci.yml)
[![GitHub Actions Linting Status](https://github.com/bigbio/quantms/actions/workflows/linting.yml/badge.svg)](https://github.com/bigbio/quantms/actions/workflows/linting.yml)[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/quantms/results)[![Cite with Zenodo](https://img.shields.io/badge/DOI-10.5281/zenodo.7754148-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.7754148)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.10.5-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nf-core/quantms)

[![Get help on Slack](https://img.shields.io/badge/slack-nf--core%20%23quantms-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/quantms)[![Follow on Twitter](https://img.shields.io/badge/twitter-%40nf__core-1DA1F2?labelColor=000000&logo=twitter)](https://twitter.com/nf_core)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](https://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**bigbio/quantms** is a bioinformatics best-practice analysis pipeline for Quantitative Mass Spectrometry (MS). Currently, the workflow supports three major MS-based analytical methods: (i) Data dependant acquisition (DDA) label-free and Isobaric quantitation (e.g. TMT, iTRAQ); (ii) Data independent acquisition (DIA) label-free quantification (for details see our in-depth documentation on [quantms](https://quantms.readthedocs.io/en/latest/)).

<p align="center">
    <img src="docs/images/quantms.png" alt="bigbio/quantms workflow overview" width="60%">
</p>

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources. The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/quantms/results). This gives you a hint on which reports and file types are produced by the pipeline in a standard run. The automatic continuous integration tests on every pull request evaluate different workflows, including peptide identification, quantification for LFQ, LFQ-DIA, and TMT test datasets.

## Pipeline summary

**bigbio/quantms** allows uses to perform analyses of three main types of analytical mass spectrometry-based quantitative methods: DDA-LFQ, DDA-ISO, DIA-LFQ. Each of these workflows share some processes but also includes their own steps. In summary:

### DDA-LFQ (data-dependent label-free quantification)

1. RAW file conversion to mzML ([`thermorawfileparser`](https://github.com/compomics/ThermoRawFileParser))
2. Peptide identification using [`comet`](https://uwpr.github.io/Comet/) and/or [`msgf+`](https://github.com/MSGFPlus/msgfplus)
3. Re-scoring peptide identifications [`percolator`](https://github.com/percolator/percolator)
4. Peptide identification FDR [`openms fdr tool`](https://github.com/bigbio/quantms/blob/dev/modules/local/openms/falsediscoveryrate/main.nf)
5. Modification localization [`luciphor`](https://github.com/dfermin/lucXor)
6. Quantification: Feature detection [`proteomicsLFQ`](https://abibuilder.cs.uni-tuebingen.de/archive/openms/Documentation/nightly/html/UTILS_ProteomicsLFQ.html)
7. Protein inference and quantification [`proteomicsLFQ`](https://abibuilder.cs.uni-tuebingen.de/archive/openms/Documentation/nightly/html/UTILS_ProteomicsLFQ.html)
8. QC report generation [`pmultiqc`](https://github.com/bigbio/pmultiqc)
9. Normalization, imputation, significance testing with [`MSstats`](https://github.com/VitekLab/MSstats)

### DDA-ISO (data-dependent quantification via isobaric labelling)

1. RAW file conversion to mzML ([`thermorawfileparser`](https://github.com/compomics/ThermoRawFileParser))
2. Peptide identification using [`comet`](https://uwpr.github.io/Comet/) and/or [`msgf+`](https://github.com/MSGFPlus/msgfplus)
3. Re-scoring peptide identifications [`percolator`](https://github.com/percolator/percolator)
4. Peptide identification FDR [`openms fdr tool`](https://github.com/bigbio/quantms/blob/dev/modules/local/openms/falsediscoveryrate/main.nf)
5. Modification localization [`luciphor`](https://github.com/dfermin/lucXor)
6. Extracts and normalizes isobaric labeling [`IsobaricAnalyzer`](https://abibuilder.cs.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_IsobaricAnalyzer.html)
7. Protein inference [`ProteinInference`](https://abibuilder.cs.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_ProteinInference.html) or [`Epifany`](https://abibuilder.cs.uni-tuebingen.de/archive/openms/Documentation/nightly/html/UTILS_Epifany.html) for bayesian inference.
8. Protein Quantification [`ProteinQuantifier`](https://abibuilder.cs.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_ProteinQuantifier.html)
9. QC report generation [`pmultiqc`](https://github.com/bigbio/pmultiqc)
10. Normalization, imputation, significance testing with [`MSstats`](https://github.com/VitekLab/MSstats)

### DIA-LFQ (data-independent label-free quantification)

1. RAW file conversion to mzML when RAW as input([`thermorawfileparser`](https://github.com/compomics/ThermoRawFileParser))
2. Performing an [optional step](https://github.com/bigbio/quantms/blob/dev/modules/local/tdf2mzml/main.nf): Converting .d to mzML when bruker data as input and set `convert_dotd` to true
3. DIA-NN analysis [`dia-nn`](https://github.com/vdemichev/DiaNN/)
4. Generation of output files (msstats)
5. QC reports generation [`pmultiqc`](https://github.com/bigbio/pmultiqc)

### Functionality overview

A graphical overview of suggested routes through the pipeline depending on context can be seen below.

<p align="center">
    <img src="docs/images/quantms_metro.png" alt="bigbio/quantms metro map" width="70%">
</p>

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, find or create a sample-to-data relationship file ([SDRF](https://github.com/bigbio/proteomics-sample-metadata)).
Have a look at public datasets that were already annotated [here](https://github.com/bigbio/proteomics-sample-metadata/tree/master/annotated-projects).
Those SDRFs should be ready for one-command re-analysis and you can just use the URL to the file on GitHub,
e.g., `https://raw.githubusercontent.com/bigbio/proteomics-sample-metadata/master/annotated-projects/PXD000396/PXD000396.sdrf.tsv`.
If you create your own, please adhere to the specifications and point the pipeline to your local folder or a remote location where you uploaded it to.

The second requirement is a protein sequence database. We suggest downloading a database for the organism(s)/proteins of interest from [Uniprot](https://www.uniprot.org/proteomes?query=*).

Now, you can run the pipeline using:

<!-- TODO nf-core: update the following command to include all required parameters for a minimal example -->

```bash
nextflow run bigbio/quantms \
   -profile <docker/singularity/.../institute> \
   --input project.sdrf.tsv \
   --database database.fasta \
   --outdir <OUTDIR>
```

> [!NOTE]
> Conda is no longer supported in this pipeline. Please use Docker, Singularity, or other container-based profiles.

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

For more details and further functionality, please refer to the [usage documentation](https://nf-co.re/quantms/usage) and the [parameter documentation](https://nf-co.re/quantms/parameters).

## Additional documentation and tutorial

The **bigbio/quantms** pipeline comes with a stand-alone [full documentation](https://quantms.readthedocs.io/en/latest/) including examples, benchmarks, and detailed explanation about the data analysis of proteomics data using quantms.

## Pipeline output

To see the results of an example test run with a full size dataset refer to the [results](https://nf-co.re/quantms/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://nf-co.re/quantms/output).

## Credits

bigbio/quantms was originally written by: Chengxin Dai ([@daichengxin](https://github.com/daichengxin)), Julianus Pfeuffer ([@jpfeuffer](https://github.com/jpfeuffer)) and Yasset Perez-Riverol ([@ypriverol](https://github.com/ypriverol)).

We thank the following people for their extensive assistance in the development of this pipeline:

- Timo Sachsenberg ([@timosachsenberg](https://github.com/timosachsenberg))
- Wang Hong ([@WangHong007](https://github.com/WangHong007))
- Henry Webel ([@enryH](https://github.com/enryH))

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#quantms` channel](https://nfcore.slack.com/channels/quantms) (you can join with [this invite](https://nf-co.re/join/slack)).

## How to cite

If you use **bigbio/quantms** for your analysis, please cite it using the following citation:

> **quantms: a cloud-based pipeline for quantitative proteomics enables the reanalysis of public proteomics data**
>
> Chengxin Dai, Julianus Pfeuffer, Hong Wang, Ping Zheng, Lukas Käll, Timo Sachsenberg, Vadim Demichev, Mingze Bai, Oliver Kohlbacher & Yasset Perez-Riverol
>
> _Nat Methods._ 2024 July 4. doi: [10.1038/s41592-024-02343-1](https://doi.org/10.1038/s41592-024-02343-1).

## Other citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use bigbio/quantms for your analysis, please cite it using the following doi: [10.5281/zenodo.7754148](https://doi.org/10.5281/zenodo.7754148) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).

```

```
