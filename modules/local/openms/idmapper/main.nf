process IDMAPPER {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(id_file), path(consensusXML)

    output:
    path "${id_file.baseName}_map.consensusXML", emit: id_map
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    IDMapper \\
        -id ${id_file} \\
        -in ${consensusXML} \\
        -threads $task.cpus \\
        -rt_tolerance $params.rt_tolerance \\
        -mz_tolerance $params.mz_tolerance \\
        -mz_measure $params.mz_measure \\
        -debug $params.db_debug \\
        -out ${id_file.baseName}_map.consensusXML \\
        > ${id_file.baseName}_map.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDMapper: \$(IDMapper 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
