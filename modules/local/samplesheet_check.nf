process SAMPLESHEET_CHECK {
    tag "$samplesheet"

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
