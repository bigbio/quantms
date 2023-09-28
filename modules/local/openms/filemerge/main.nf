process FILEMERGE {
    label 'process_medium'
    label 'process_single'
    label 'openms'

    conda "bioconda::openms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.9.1--h135471a_0' :
        'biocontainers/openms:2.9.1--h135471a_0' }"

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
        2>&1 | tee ID_mapper_merge.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        FileMerger: \$(FileMerger 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
