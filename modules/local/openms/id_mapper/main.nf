process ID_MAPPER {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
    tuple val(meta), path(id_file), path(map_file)

    output:
    path "${id_file.baseName}_map.consensusXML", emit: id_map
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    IDMapper \\
        -id ${id_file} \\
        -in ${map_file} \\
        -threads $task.cpus \\
        -out ${id_file.baseName}_map.consensusXML \\
        $args \\
        2>&1 | tee ${id_file.baseName}_map.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDMapper: \$(IDMapper 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
