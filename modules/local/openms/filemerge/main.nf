process FILEMERGE {
    label 'process_medium'
    label 'process_single'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:3.3.0--h9ee0642_8' :
        'biocontainers/openms-thirdparty:3.3.0--h9ee0642_8' }"

    input:
    file(id_map)

    output:
    tuple val([:]), path("ID_mapper_merge.consensusXML"), emit: id_merge
    path "versions.yml", emit: versions
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
        2>&1 | tee ID_mapper_merge.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        FileMerger: \$(FileMerger 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
