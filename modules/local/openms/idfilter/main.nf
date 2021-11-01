// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process IDFILTER {
    label 'process_vrey_low'
    label 'process_single_thread'
    publishDir "${params.outdir}/logs",
        mode: params.publish_dir_mode,
        pattern: "*.log",
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    publishDir "${params.outdir}/ids",
        mode: params.publish_dir_mode,
        pattern: "*.idXML",
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
    tuple mzml_id, path "${id_file.baseName}_filter.idXML", emit: id_filtered
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    IDFilter \\
        -in ${id_file} \\
        -out ${id_file.baseName}_filter.idXML \\
        -threads $task.cpus \\
        $options.delete_unreferenced_peptide_hits \\
        $options.remove_decoys \\
        $options.remove_shared_peptides \\
        -missed_cleavages $options.missed_cleavages \\
        -score:$options.score_level $options.fdr_cut_cutoff \\
        -debug 10 \\


    echo \$(IDFilter --version 2>&1) > ${software}.version.txt
    """
}
