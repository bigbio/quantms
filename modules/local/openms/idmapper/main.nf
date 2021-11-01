// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process IDMAPPER {
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms:2.6.0--h4afb90d_0"
    } else {
        container "quay.io/biocontainers/openms:2.6.0--h4afb90d_0"
    }

    input:
    tuple mzml_id, path id_file
    path consensusXML

    output:
    path "${id_file.baseName}_map.consensusXML", emit: id_map
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    IDMapper \\
        -in ${id_file} \\
        -threads $task.cpus \\
        -rt_tolerance $options.rt_tolerance \\
        -mz_tolerance $options.mz_tolerance \\
        -mz_measure $options.mz_measure \\
        -mz_reference $options.mz_reference \\
        -debug $options.map_debug \\
        -out ${id_file.baseName}_map.consensusXML \\
        > ${id_file.baseName}_map.log

    echo \$(IDMapper --version 2>&1) > ${software}.version.txt
    """
}
