// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process LUCIPHORADAPTER {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "conda-forge::gnuplot openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.6.0--0"
    } else {
        container "quay.io/biocontainers/openms-thirdparty:2.6.0--0"
    }

    input:
    tuple val(meta), path(mzml_file), path(id_file)


    output:
    tuple val(meta), path("${id_file.baseName}_luciphor.idXML"), emit: ptm_in_id_luciphor
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    def losses = args.luciphor_neutral_losses ? '-neutral_loss "$params.luciphor_neutral_losses"' : ''
    def dec_mass = args.luciphor_decoy_mass ? '-decoy_mass "${params}.luciphor_decoy_mass"' : ''
    def dec_losses = args.luciphor_decoy_neutral_losses ? '-decoy_neutral_losses "${params}.luciphor_decoy_neutral_losses"' : ''

    """
    LuciphorAdapter \\
        -id ${id_file} \\
        -in ${mzml_file} \\
        -out ${id_file.baseName}_luciphor.idXML \\
        -threads $task.cpus \\
        -num_threads $task.cpus \\
        -target_modifications $params.mod_localization \\
        -fragment_method $meta.DissociationMethod \\
        ${losses} \\
        ${dec_mass} \\
        ${dec_losses} \\
        -max_charge_state $params.max_precursor_charge \\
        -max_peptide_length $params.max_peptide_length \\
        -debug $params.luciphor_debug \\
        > ${id_file.baseName}_luciphor.log

    echo \$(LuciphorAdapter 2>&1) > ${software}.version.txt
    """
}
