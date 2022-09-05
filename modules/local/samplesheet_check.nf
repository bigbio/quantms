process SAMPLESHEET_CHECK {

    conda (params.enable_conda ? "bioconda::sdrf-pipelines=0.0.21" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.21--pyhdfd78af_0' :
        'quay.io/biocontainers/sdrf-pipelines:0.0.21--pyhdfd78af_0' }"

    input:
    path input_file
    val is_sdrf

    output:
    path "*.log", emit: log
    path "${input_file}", emit: checked_file
    path "versions.yml", emit: versions

    script: // This script is bundled with the pipeline, in nf-core/quantms/bin/
    // TODO validate experimental design file
    def args = task.ext.args ?: ''

    """
    check_samplesheet.py "${input_file}" ${is_sdrf} --CHECK_MS |& tee input_check.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(echo "0.0.21")
    END_VERSIONS
    """
}
