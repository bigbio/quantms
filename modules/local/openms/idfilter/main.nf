process IDFILTER {
    tag "$meta.id"

    label 'process_very_low'
    label 'process_single_thread'
    label 'openms'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.8.0--h7ca0330_1' :
        'quay.io/biocontainers/openms:2.8.0--h7ca0330_1' }"

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
        > ${id_file.baseName}_idfilter.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDFilter: \$(IDFilter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
