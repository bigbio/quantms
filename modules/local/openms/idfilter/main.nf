process IDFILTER {
    label 'process_vrey_low'
    label 'process_single_thread'

    conda (params.enable_conda ? "openms::openms=2.8.0.dev" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.7.0--h9ee0642_1' :
        'quay.io/biocontainers/openms-thirdparty:2.7.0--h9ee0642_1' }"

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_filter$task.ext.suffix"), emit: id_filtered
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def suffix = task.ext.suffix

    """
    IDFilter \\
        -in ${id_file} \\
        -out ${id_file.baseName}_filter$suffix \\
        -threads $task.cpus \\
        $args \\
        -debug 10 \\
        > ${id_file.baseName}_idfilter.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDFilter:  echo \$(IDFilter 2>&1)
    END_VERSIONS
    """
}
