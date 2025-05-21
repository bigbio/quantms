process PROTEIN_INFERENCE {
    label 'process_medium'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
    tuple val(meta), path(consus_file)

    output:
    tuple val(meta), path("${consus_file.baseName}_epi.consensusXML"), emit: protein_inference
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    gg = params.protein_quant == 'shared_peptides' ? '-Algorithm:greedy_group_resolution' : ''
    groups = params.protein_quant == 'strictly_unique_peptides' ? 'false' : 'true'

    """
    ProteinInference \\
        -in ${consus_file} \\
        -threads $task.cpus \\
        -picked_fdr $params.picked_fdr \\
        -picked_decoy_string $params.decoy_string \\
        -protein_fdr true \\
        -Algorithm:use_shared_peptides $params.use_shared_peptides \\
        -Algorithm:annotate_indistinguishable_groups $groups \\
        -Algorithm:score_type "PEP" \\
        $gg \\
        -Algorithm:score_aggregation_method $params.protein_score \\
        -Algorithm:min_peptides_per_protein $params.min_peptides_per_protein \\
        -out ${consus_file.baseName}_epi.consensusXML \\
        $args \\
        2>&1 | tee ${consus_file.baseName}_inference.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ProteinInference: \$(ProteinInference 2>&1 | grep -E '^Version(.*) ' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
