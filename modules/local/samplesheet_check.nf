process SAMPLESHEET_CHECK {

    tag "$input_file"
    label 'process_single'

    conda "bioconda::sdrf-pipelines=0.0.29"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.29--pyhdfd78af_0' :
        'biocontainers/sdrf-pipelines:0.0.29--pyhdfd78af_0' }"

    input:
    path input_file
    val is_sdrf
    val validate_ontologies

    output:
    path "*.log", emit: log
    path "${input_file}", emit: checked_file
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-core/quantms/bin/
    // TODO validate experimental design file
    def args = task.ext.args ?: ''

    """
    check_samplesheet.py "${input_file}" ${is_sdrf} ${validate_ontologies} --CHECK_MS 2>&1 | tee input_check.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(parse_sdrf --version 2>&1 | awk -F ' ' '{print \$2}')
    END_VERSIONS
    """
}
