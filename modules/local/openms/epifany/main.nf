process EPIFANY {
    label 'process_medium'
    publishDir "${params.outdir}",

    conda (params.enable_conda ? "bioconda::openms=2.8.0 bioconda::openms-thirdparty=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(consus_file)

    output:
    tuple val(meta), path("${consus_file.baseName}_epi.consensusXML"), emit: epi_inference
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    """
    Epifany \\
        -in ${consus_file} \\
        -protein_fdr true \\
        -threads $task.cpus \\
        -debug $params.debug \\
        -algorithm:keep_best_PSM_only $params.keep_best_PSM_only \\
        -algorithm:update_PSM_probabilities $params.update_PSM_probabilities \\
        -greedy_group_resolution $params.greedy_group_resolution \\
        -algorithm:top_PSMs $params.top_PSMs \\
        -out ${consus_file.baseName}_epi.consensusXML \\
        > ${consus_file.baseName}_inference.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DecoyDatabase: \$(Epifany 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
