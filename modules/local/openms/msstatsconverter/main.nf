process MSSTATSCONVERTER {
    label 'process_low'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

    input:
    path consensusXML
    path exp_file
    val quant_method

    output:
    path "*.csv", emit: out_msstats
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    """
    MSstatsConverter \\
        -in ${consensusXML} \\
        -in_design ${exp_file} \\
        -method ${quant_method} \\
        -out out_msstats.csv \\
        -debug $params.db_debug \\
        > MSstatsConverter.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MSstatsConverter: \$(MSstatsConverter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
