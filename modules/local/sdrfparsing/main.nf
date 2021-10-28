// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SDRFPARSING {
    label 'process_low'
    publishDir "${params.outdir/logs}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "bioconda::sdrf-pipelines=0.0.8" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.18--py_0"
    } else {
        container "quay.io/biocontainers/sdrf-pipelines:0.0.18--py_0"
    }

    input:
    file sdrf from ch_sdrf

    output:
    path "experimental_design.tsv", emit: ch_expdesign, ch_pro_quant_exp, ch_expdesign_multiqc
    path "openms.tsv"             , emit: ch_sdrf_config_file

    script:
    def software = getSoftwareName(task.process)
    """
    ## -t2 since the one-table format parser is broken in OpenMS2.5
    ## -l for legacy behavior to always add sample columns
    parse_sdrf convert-openms -t2 -l -s ${sdrf} > sdrf_parsing.log
    """
}
