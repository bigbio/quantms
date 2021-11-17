// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process FALSEDISCOVERYRATE {
    label 'process_very_low'
    label 'process_single_thread'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://ftp.pride.ebi.ac.uk/pride/data/tools/quantms-dev.sif"
    } else {
        container "quay.io/bigbio/quantms:dev"
    }

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_fdr.idXML"), emit: id_files_idx_ForIDPEP_FDR
    path "*.version.txt", emit: version
    path "*.log", emit: log
    script:
    def software = getSoftwareName(task.process)

    """
    FalseDiscoveryRate \\
        -in ${id_file} \\
        -out ${id_file.baseName}_fdr.idXML \\
        -threads $task.cpus \\
        -protein false \\
        -algorithm:add_decoy_peptides \\
        -algorithm:add_decoy_proteins \\
        $options.args \\
        > ${id_file.baseName}_fdr.log

    echo \$(FalseDiscoveryRate 2>&1) > ${software}.version.txt
    """
}
