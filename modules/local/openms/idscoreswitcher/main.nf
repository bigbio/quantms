// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process IDSCORESWITCHER {
    label 'process_very_low'
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
    tuple mzml_id, path id_file

    output:
    tuple mzml_id, path "${id_file.baseName}_pep.idXML", emit: id_score_switcher
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    IDScoreSwitcher \\
        -in ${id_file} \\
        -out ${id_file.baseName}_pep.idXML \\
        -threads $task.cpus \\
        -old_score $options.old_score \\
        -new_score $options.new_score \\
        -new_score_type $options.new_score_type \\
        -new_score_orientation $options.new_score_orientation \\
        > ${id_file.baseName}_switch.log

    echo \$(IDScoreSwitcher --version 2>&1) > ${software}.version.txt
    """
}
