process IDMAPPER {
    tag "$meta.id"

    label 'process_medium'
    label 'openms'

    conda (params.enable_conda ? "bioconda::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://ftp.pride.ebi.ac.uk/pub/databases/pride/resources/tools/ghcr.io-openms-openms-executables-latest.img' :
        'ghcr.io/openms/openms-executables:latest' }"

    input:
    tuple val(meta), path(id_file), path(map_file)

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
        -in ${map_file} \\
        -threads $task.cpus \\
        -out ${id_file.baseName}_map.consensusXML \\
        $args \\
        |& tee ${id_file.baseName}_map.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDMapper: \$(IDMapper 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
