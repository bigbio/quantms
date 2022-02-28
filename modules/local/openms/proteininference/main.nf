process PROTEININFERENCE {
    label 'process_medium'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://ftp.pride.ebi.ac.uk/pride/data/tools/quantms-dev.sif' :
        'quay.io/bigbio/quantms:dev' }"

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
        -debug 100 \\
        -Algorithm:min_peptides_per_protein $params.min_peptides_per_protein \\
        -out ${consus_file.baseName}_epi.consensusXML \\
        > ${consus_file.baseName}_inference.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ProteinInference: echo \$(ProteinInference 2>&1)
    END_VERSIONS
    """
}
