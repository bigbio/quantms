process IDCONFLICTRESOLVER {
    label 'process_medium'

    conda (params.enable_conda ? "openms::openms=2.8.0.dev" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.7.0--h9ee0642_1' :
        'quay.io/biocontainers/openms-thirdparty:2.7.0--h9ee0642_1' }"

    input:
    path consus_file

    output:
    path "${consus_file.baseName}_resconf.consensusXML", emit: pro_resconf
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    """
    IDConflictResolver \\
        -in ${consus_file} \\
        -threads $task.cpus \\
        -debug 100 \\
        -resolve_between_features $params.res_between_fet \\
        -out ${consus_file.baseName}_resconf.consensusXML \\
        > ${consus_file.baseName}_resconf.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDConflictResolver: echo \$(IDConflictResolver 2>&1)
    END_VERSIONS
    """
}
