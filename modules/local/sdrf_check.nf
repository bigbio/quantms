// Import generic module functions
include { initOptions; saveFiles } from './functions'

params.options = [:]

options = initOptions(params.options)

process SDRF_CHECK {
    tag "$sdrf_file"
    label "process_single_thread"
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:'pipeline_info', meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "bioconda::sdrf-pipelines=0.0.18" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.18--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/sdrf-pipelines:0.0.18--pyhdfd78af_0"
    }

    input:
    path sdrf_file

    output:
    path "*.log", emit: log
    path "${sdrf_file}", emit: sdrf

    script: // This script is bundled with the pipeline, in nf-core/quantms/bin/
    """
    check_sdrf.py $options.template "${sdrf_file}" $options.check_ms  > sdrf_check.log
    """
}
