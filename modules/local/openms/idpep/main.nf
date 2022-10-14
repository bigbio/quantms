process IDPEP {
    tag "$meta.id"
    label 'process_very_low'

    conda (params.enable_conda ? "bioconda::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://ftp.pride.ebi.ac.uk/pub/databases/pride/resources/tools/ghcr.io-openms-openms-executables-latest.img' :
        'ghcr.io/openms/openms-executables:latest' }"

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
