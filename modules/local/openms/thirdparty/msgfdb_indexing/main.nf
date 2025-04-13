process MSGFDBINDEXING {
    tag "$database.baseName"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/msgf_plus:2024.03.26--hdfd78af_0' :
        'biocontainers/msgf_plus:2024.03.26--hdfd78af_0' }"

    input:
    path(database)

    output:
    tuple path("${database.baseName}.cnlcp"), path("${database.baseName}.canno"), path("${database.baseName}.csarr"), path("${database.baseName}.cseq"), emit: msgfdb_idx
    path "versions.yml",   emit: versions
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''

    """
    msgf_plus edu.ucsd.msjava.msdbsearch.BuildSA \\
        -d ${database} \\
        -Xmx${task.memory.toMega()}m \\
        -Xms${task.memory.toMega()}m \\
        -o ./ \\
        -tda 0 \\
        -debug $params.db_debug \\
        $args \\
        2>&1 | tee ${database.baseName}_msgfdb_idx.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msgf_plus: \$(msgf_plus 2>&1 | grep -E '^MS-GF\\+ Release.*')
    END_VERSIONS
    """
}
