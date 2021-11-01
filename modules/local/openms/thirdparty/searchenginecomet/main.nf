// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SEARCHENGINECOMET {
    label 'process_medium'
    publishDir "${params.outdir}/logs",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.6.0--0"
    } else {
        container "quay.io/biocontainers/openms-thirdparty:2.6.0--0"
    }

    input:
    tuple val(mzml_id), path (mzml_file)
    path(database)

    output:
    tuple mzml_id, path "${mzml_file.baseName}_comet.idXML",  emit: id_files_comet
    path "*.version.txt",   emit: version
    path "*.log",   emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    CometAdapter \\
        -in ${mzml_file} \\
        -out ${mzml_file.baseName}_comet.idXML
        -threads $task.cpus \\
        -database "$options.database" \\
        -instrument $options.inst \\
        -missed_cleavages $options.allowed_missed_cleavages \\
        -min_peptide_length $options.min_peptide_length \\
        -max_peptide_length $options.max_peptide_length \\
        -num_hits $options.num_hits \\
        -num_enzyme_termini $options.num_enzyme_termini \\
        -enzyme $options.enzyme \\
        -isotope_error $options.isoSlashComet \\
        -precursor_charge $options.min_precursor_charge:$options.max_precursor_charge
        -fixed_modifications $options.fixed \\
        -variable_modifications $options.variable \\
        -max_variable_mods_in_peptide $options.max_mods \\
        -precursor_mass_tolerance $options.prec_tol \\
        -precursor_error_units $options.prec_tol_unit \\
        -fragment_mass_tolerance $options.bin_tol \\
        -fragment_bin_offset $options.bin_offset \\
        -debug $options.db_debug \\
        -force \\
        > ${mzml_file.baseName}_comet.log

    echo \$(CometAdapter --version 2>&1) > ${software}.version.txt
    """
}
