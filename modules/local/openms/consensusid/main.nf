process CONSENSUSID {
    label 'process_medium'
    // TODO could be easily parallelized
    label 'process_single_thread'
    label 'openms'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.8.0--h7ca0330_1' :
        'quay.io/biocontainers/openms:2.8.0--h7ca0330_1' }"

    input:
    tuple val(meta), path(id_file), val(qval_score)

    output:
    tuple val(meta), path("${meta.id}_consensus.idXML"), emit: consensusids
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    ConsensusID \\
        -in ${id_file} \\
        -out ${meta.id}_consensus.idXML \\
        -per_spectrum \\
        -threads $task.cpus \\
        -algorithm $params.consensusid_algorithm \\
        -filter:min_support $params.min_consensus_support \\
        -filter:considered_hits $params.consensusid_considered_top_hits \\
        -debug $params.consensusid_debug \\
        $args \\
        > ${meta.id}_consensusID.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ConsensusID: \$(ConsensusID 2>&1  | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
