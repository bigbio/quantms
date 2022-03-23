process IDSCORESWITCHER {
    tag "$meta.id"
    label 'process_very_low'
    label 'process_single_thread'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(id_file), val(new_score)

    output:
    tuple val(meta), path("${id_file.baseName}_pep.idXML"), emit: id_score_switcher
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    IDScoreSwitcher \\
        -in ${id_file} \\
        -out ${id_file.baseName}_pep.idXML \\
        -threads $task.cpus \\
        -new_score ${new_score} \\
        $args \\
        -debug $params.db_debug \\
        > ${id_file.baseName}_switch.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDScoreSwitcher: \$(IDScoreSwitcher 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
