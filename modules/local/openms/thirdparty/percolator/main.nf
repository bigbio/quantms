// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process PERCOLATOR {
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.6.0--0"
    } else {
        container "quay.io/biocontainers/openms-thirdparty:2.6.0--0"
    }

    input:
    tuple mzml_id, path id_file

    output:
    tuple mzml_id, path "${id_file.baseName}_perc.idXML", emit: id_files_perc
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    OMP_NUM_THREADS=$task.cpus PercolatorAdapter \\
        -in ${id_file} \\
        -out ${id_file.baseName}_perc.idXML \\
        -threads $task.cpus \\
        -subset_max_train $options.subset_max_train \\
        -decoy_pattern $options.decoy_affix \\
        -post_processing_tdx \\
        -score_type pep \\
        > ${id_file.baseName}_percolator.log

    echo \$(PercolatorAdapter --version 2>&1) > ${software}.version.txt
    """
}
