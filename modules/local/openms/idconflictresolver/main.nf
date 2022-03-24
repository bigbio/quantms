process IDCONFLICTRESOLVER {
    label 'process_low'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

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
        -debug $params.conflict_resolver_debug \\
        -out ${consus_file.baseName}_resconf.consensusXML \\
        > ${consus_file.baseName}_resconf.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDConflictResolver: \$(IDConflictResolver 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
