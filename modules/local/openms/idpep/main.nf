process IDPEP {
    label 'process_very_low'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.8.0--h7ca0330_1' :
        'quay.io/biocontainers/openms:2.8.0--h7ca0330_1' }"

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_idpep.idXML"), val("q-value_score"), emit: id_files_ForIDPEP
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    IDPosteriorErrorProbability \\
        -in ${id_file} \\
        -out ${id_file.baseName}_idpep.idXML \\
        -fit_algorithm:outlier_handling $params.outlier_handling \\
        -threads ${task.cpus} \\
        $args \\
        |& tee ${id_file.baseName}_idpep.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDPosteriorErrorProbability: \$(IDPosteriorErrorProbability 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
