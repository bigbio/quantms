process FILEMERGE {
    label 'process_medium'
    label 'process_single_thread'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.8.0--h7ca0330_1' :
        'quay.io/biocontainers/openms:2.8.0--h7ca0330_1' }"

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
        -threads $task.cpus \\
        -out ID_mapper_merge.consensusXML \\
        $args \\
        > ID_mapper_merge.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        FileMerger: \$(FileMerger 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
