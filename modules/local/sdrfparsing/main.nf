// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SDRFPARSING {
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.20" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.20--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/sdrf-pipelines:0.0.20--pyhdfd78af_0"
    }

    input:
    path sdrf

    output:
    path "experimental_design.tsv", optional:true, emit: ch_expdesign
    path "openms.tsv", optional:true, emit: ch_sdrf_config_file
    path "*.xml", optional:true, emit: mqpar
    path "*.log", emit: log
    path "*.version.txt", emit: version

    script:
    def software = getSoftwareName(task.process)
    """
    ## -t2 since the one-table format parser is broken in OpenMS2.5
    ## -l for legacy behavior to always add sample columns
    ## TODO Update the sdrf-pipelines to dynamic print versions

    parse_sdrf $options.args -s ${sdrf} > sdrf_parsing.log

    echo "0.0.20" > sdrf-pipelines.version.txt
    """
}
