process CONSENSUSID {
    tag "$meta.mzml_id"
    label 'process_medium'
    // TODO could be easily parallelized
    label 'process_single_thread'
    label 'openms'

    conda (params.enable_conda ? "bioconda::openms=2.9.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.9.0--h135471a_0' :
        'quay.io/biocontainers/openms:2.9.0--h135471a_0' }"

    input:
    tuple val(meta), path(id_file), val(qval_score)

    output:
    tuple val(meta), path("${meta.mzml_id}_consensus.idXML"), emit: consensusids
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    ConsensusID \\
        -in ${id_file} \\
        -out ${meta.mzml_id}_consensus.idXML \\
        -per_spectrum \\
        -threads $task.cpus \\
        -algorithm $params.consensusid_algorithm \\
        -filter:min_support $params.min_consensus_support \\
        -filter:considered_hits $params.consensusid_considered_top_hits \\
        -debug $params.consensusid_debug \\
        $args \\
        |& tee ${meta.id}_consensusID.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ConsensusID: \$(ConsensusID 2>&1  | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
