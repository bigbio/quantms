process FILEMERGE {
    label 'process_medium'
    label 'process_single_thread'

    conda (params.enable_conda ? "openms::openms=2.8.0.dev" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.7.0--h9ee0642_1' :
        'quay.io/biocontainers/openms-thirdparty:2.7.0--h9ee0642_1' }"

    input:
    file(id_map)

    output:
    tuple val([:]), path("ID_mapper_merge.consensusXML"), emit: id_merge
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    """
    FileMerger \\
        -in ${(id_map as List).join(' ')} \\
        -in_type consensusXML \\
        -annotate_file_origin \\
        -append_method 'append_cols' \\
        -debug 10 \\
        -threads $task.cpus \\
        -out ID_mapper_merge.consensusXML \\
        > ID_mapper_merge.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        FileMerger: echo \$(FileMerger 2>&1)
    END_VERSIONS
    """
}
