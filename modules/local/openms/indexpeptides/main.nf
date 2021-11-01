// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process INDEXPEPTIDES {
    label 'process_low'
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
    path database

    output:
    tuple mzml_id, path "${id_file.baseName}_idx.idXML", emit: id_files_idx
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    PeptideIndexer \\
        -in ${id_file} \\
        -threads $task.cpus \\
        -fasta ${database} \\
        -enzyme:name "$options.enzyme" \\
        -enzyme:specificity $options.num_enzyme_termini \\
        $options.il \\
        $options.allow_um \\
        > ${id_file.baseName}_index_peptides.log

    echo \$(PeptideIndexer --version 2>&1) > ${software}.version.txt
    """
}
