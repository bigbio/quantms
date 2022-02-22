process MSSTATSCONVERTER {
    label 'process_medium'

    conda (params.enable_conda ? "openms::openms=2.8.0.dev" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.7.0--h9ee0642_1' :
        'quay.io/biocontainers/openms-thirdparty:2.7.0--h9ee0642_1' }"

    input:
    path consensusXML
    path exp_file

    output:
    path "*.csv", emit: out_msstats
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    if ( params.labelling_type.contains('tmt') | params.labelling_type.contains("itraq")) {
        quant_method = "ISO"
    } else if ( params.labelling_type.contains('label free')) {
        quant_method = "LFQ"
    }

    """
    MSstatsConverter \\
        -in ${consensusXML} \\
        -in_design ${exp_file} \\
        -method ${quant_method} \\
        -out out_msstats.csv \\
        -debug 100 \\
        > MSstatsConverter.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MSstatsConverter: echo \$(MSstatsConverter 2>&1)
    END_VERSIONS
    """
}
