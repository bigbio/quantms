process SAMPLESHEET_CHECK {

    conda (params.enable_conda ? "conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.20" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.20--pyhdfd78af_0' :
        'quay.io/biocontainers/sdrf-pipelines:0.0.20--pyhdfd78af_0' }"

    input:
    path input_file
    val is_sdrf

    output:
    path "*.log", emit: log
    path "${input_file}", emit: checked_file
    path "versions.yml", emit: versions

    script: // This script is bundled with the pipeline, in nf-core/quantms/bin/
    // TODO validate experimental design file  check_samplesheet.py $args "${input_file}" ${is_sdrf} > input_check.log
    def args = task.ext.args ?: ''

    """
    echo 1111 > input_check.log

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
