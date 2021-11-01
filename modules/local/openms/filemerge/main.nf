// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process FILEMERGE {
    label 'process_medium'
    label 'process_single_thread'
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
    file id_map

    output:
    path "ID_mapper_merge.consensusXML", emit: id_merge
    path "*.version.txt", emit: version
    params "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    FileMerger \\
        -in ${(id_map as List).join(' ')} \\
        -in_type consensusXML \\
        -annotate_file_origin \\
        -append_method 'append_cols' \\
        -debug $openms.merge_debug \\
        -threads $task.cpus \\
        -out ID_mapper_merge.consensusXML \\
        > ID_mapper_merge.log

    echo \$(FileMerger --version 2>&1) > ${software}.version.txt
    """
}
