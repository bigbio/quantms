// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process MSSTATSCONVERTER {
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms=2.8.0.dev" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.7.0--h9ee0642_1"
    } else {
        container "quay.io/biocontainers/openms-thirdparty:2.7.0--h9ee0642_1"
    }

    input:
    path consensusXML
    path exp_file

    output:
    path "*.csv", emit: out_msstats
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    MSstatsConverter \\
        -in ${consensusXML} \\
        -in_design ${exp_file} \\
        -method $params.quant_method \\
        -out out_msstats.csv \\
        -debug 100 \\
        > MSstatsConverter.log

    echo \$(MSstatsConverter 2>&1) > ${software}.version.txt
    """
}
