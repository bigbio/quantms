process PROTEININFERENCE {
    label 'process_medium'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.8.0--h7ca0330_1' :
        'quay.io/biocontainers/openms:2.8.0--h7ca0330_1' }"

    input:
    tuple val(meta), path(consus_file)

    output:
    tuple val(meta), path("${consus_file.baseName}_epi.consensusXML"), emit: protein_inference
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    """
    ProteinInference \\
        -in ${consus_file} \\
        -threads $task.cpus \\
        -picked_fdr $params.picked_fdr \\
        -picked_decoy_string $params.decoy_string \\
        -protein_fdr true \\
        -Algorithm:score_aggregation_method $params.protein_score \\
        -Algorithm:min_peptides_per_protein $params.min_peptides_per_protein \\
        -out ${consus_file.baseName}_epi.consensusXML \\
        $args \\
        > ${consus_file.baseName}_inference.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ProteinInference: \$(ProteinInference 2>&1 | grep -E '^Version(.*) ' | sed 's/Version: //g')
    END_VERSIONS
    """
}
