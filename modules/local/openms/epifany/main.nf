process EPIFANY {
    label 'process_medium'
    label 'openms'

    conda "bioconda::openms-thirdparty=3.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:3.3.0--h9ee0642_4' :
        'biocontainers/openms-thirdparty:3.3.0--h9ee0642_4' }"

    input:
    tuple val(meta), path(consus_file)

    output:
    tuple val(meta), path("${consus_file.baseName}_epi.consensusXML"), emit: epi_inference
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    gg = params.protein_quant == 'shared_peptides' ? 'remove_proteins_wo_evidence' : 'none'

    """
    Epifany \\
        -in ${consus_file} \\
        -protein_fdr true \\
        -threads $task.cpus \\
        -algorithm:keep_best_PSM_only $params.keep_best_PSM_only \\
        -algorithm:update_PSM_probabilities $params.update_PSM_probabilities \\
        -greedy_group_resolution $gg \\
        -algorithm:top_PSMs $params.top_PSMs \\
        -out ${consus_file.baseName}_epi.consensusXML \\
        $args \\
        2>&1 | tee ${consus_file.baseName}_inference.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Epifany: \$(Epifany 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
