process IDPEP {
    tag "$meta.mzml_id"
    label 'process_very_low'

    conda (params.enable_conda ? "bioconda::openms=2.9.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.9.0--h135471a_0' :
        'quay.io/biocontainers/openms:2.9.0--h135471a_0' }"

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_idpep.idXML"), val("q-value_score"), emit: id_files_ForIDPEP
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

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
        IDPosteriorErrorProbability: \$(IDPosteriorErrorProbability 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
