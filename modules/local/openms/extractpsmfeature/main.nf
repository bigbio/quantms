// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process EXTRACTPSMFEATURE {
    label 'process_very_low'
    label 'process_single_thread'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "bioconda::openms=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms:2.6.0--h4afb90d_0"
    } else {
        container "quay.io/biocontainers/openms:2.6.0--h4afb90d_0"
    }

    input:
    tuple mzml_id, path id_file

    output:
    tuple mzml_id, path "${id_file.baseName}_feat.idXML", emit: id_files_idx_feat
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    PSMFeatureExtractor \\
        -in ${id_file} \\
        -out ${id_file.baseName}_feat.idXML \\
        -threads $task.cpus \\
        > ${id_file.baseName}_extract_psm_feature.log

    echo \$(PSMFeatureExtractor --version 2>&1) > ${software}.version.txt
    """
}
