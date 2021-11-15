// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process IDCONFLICTRESOLVER {
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
    path consus_file

    output:
    path "${consus_file.baseName}_resconf.consensusXML", emit: pro_resconf
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    IDConflictResolver \\
        -in ${consus_file} \\
        -threads $task.cpus \\
        -debug 100 \\
        -resolve_between_features $params.res_between_fet \\
        -out ${consus_file.baseName}_resconf.consensusXML \\
        > ${consus_file.baseName}_resconf.log

    echo \$(IDConflictResolver 2>&1) > ${software}.version.txt
    """
}
