// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process OPENMSPEAKPICKER {
    label 'process_low'
    publishDir "${params.outdir}/logs",
        mode: params.publish_dir_mode,
        pattern: "*.log"
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms:2.6.0--h4afb90d_0"
    } else {
        container "quay.io/biocontainers/openms:2.6.0--h4afb90d_0"
    }

    input:
    tuple mzml_id, path mzml_file

    output:
    tuple mzml_id, path "*.mzML",   emit: mzmls_picked
    path "*.version.txt",   emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    PeakPickerHiRes \\
        -in ${mzml_file} \\
        -out ${mzml_file.baseName}.mzML \\
        -threads $task.cpus \\
        -debug $options.pp_debug \\
        -processOption $options.peakpicking_inmemory \\
        $options.peakpicking_ms_levels \\
        > ${mzml_file.baseName}_pp_log

    echo \$(PeakPickerHiRes --version 2>&1) > ${software}.version.txt
    """
}
