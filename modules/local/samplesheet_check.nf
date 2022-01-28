// Import generic module functions
include { initOptions; saveFiles } from './functions'

params.options = [:]

options = initOptions(params.options)

process SAMPLESHEET_CHECK {
    tag "$input_file"
    label "process_single_thread"
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:'pipeline_info', meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.20" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.20--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/sdrf-pipelines:0.0.20--pyhdfd78af_0"
    }

    input:
    path input_file
    val is_sdrf

    output:
    path "*.log", emit: log
    path "${input_file}", emit: checked_file

    script: // This script is bundled with the pipeline, in nf-core/quantms/bin/
    // TODO validate experimental design file
    """
    check_samplesheet.py $options.template "${input_file}" ${is_sdrf} $options.check_ms > input_check.log
    """
}
