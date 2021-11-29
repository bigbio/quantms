// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process IDMAPPER {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://ftp.pride.ebi.ac.uk/pride/data/tools/quantms-dev.sif"
    } else {
        container "quay.io/bigbio/quantms:dev"
    }

    input:
    tuple val(meta), path(id_file), path(consensusXML)

    output:
    path "${id_file.baseName}_map.consensusXML", emit: id_map
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    IDMapper \\
        -id ${id_file} \\
        -in ${consensusXML} \\
        -threads $task.cpus \\
        -rt_tolerance $params.rt_tolerance \\
        -mz_tolerance $params.mz_tolerance \\
        -mz_measure $params.mz_measure \\
        -mz_reference $params.mz_reference \\
        -debug 100 \\
        -out ${id_file.baseName}_map.consensusXML \\
        > ${id_file.baseName}_map.log

    echo \$(IDMapper 2>&1) > ${software}.version.txt
    """
}
