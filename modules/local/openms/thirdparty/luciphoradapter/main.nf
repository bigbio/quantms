// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process LUCIPHORADAPTER {
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
    tuple mzml_id, path mzml_file
    path id_file

    output:
    tuple mzml_id, path "${id_file.baseName}_luciphor.idXML", emit: ptm_in_id_luciphor
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    LuciphorAdapter \\
        -id ${id_file} \\
        -in ${mzml_file} \\
        -out ${id_file.baseName}_luciphor.idXML \\
        -threads $task.cpus \\
        -num_threads $task.cpus \\
        -target_modifications $options.mod_localization \\
        -fragment_method $options.frag_method \\
        $options.losses \\
        $options.dec_mass \\
        $options.dec_losses \\
        -max_charge_state $options.max_precursor_charge \\
        -max_peptide_length $options.max_peptide_length \\
        -debug $options.luciphor_debug \\
        > ${id_file.baseName}_luciphor.log

    echo \$(LuciphorAdapter --version 2>&1) > ${software}.version.txt
    """
}
