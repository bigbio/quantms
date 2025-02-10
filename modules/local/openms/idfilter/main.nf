process IDFILTER {
    tag {task.ext.suffix == ".idXML" ? "$meta.mzml_id" : "$id_file.baseName"}
    label 'process_very_low'
    label 'process_single'
    label 'openms'

    conda "bioconda::openms-thirdparty=3.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:3.3.0--h9ee0642_4' :
        'biocontainers/openms-thirdparty:3.3.0--h9ee0642_4' }"

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_filter$task.ext.suffix"), emit: id_filtered
    path "versions.yml", emit: versions
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
        2>&1 | tee ${id_file.baseName}_idfilter.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDFilter: \$(IDFilter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
