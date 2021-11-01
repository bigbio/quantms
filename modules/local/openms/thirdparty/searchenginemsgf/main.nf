// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SEARCHENGINEMSGF {
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
    tuple val(mzml_id), path (mzml_file)
    path(database)

    output:
    tuple mzml_id, path "${mzml_file.baseName}_msgf.idXML",  emit: id_files_msgf
    path "*.version.txt",   emit: version
    path "*.log",   emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    MSGFPlusAdapter \\
        -protocol $options.protocol \\
        -in ${mzml_file} \\
        -threads $task.cpus \\
        -java_memory $task.java_memory.toMega() \\
        -database $options.database \\
        -instrument $options.inst \\
        -matches_per_spec $options.num_hits \\
        -min_precursor_charge $options.min_precursor_charge \\
        -max_precursor_charge $options.max_precursor_charge \\
        -min_peptide_length $options.min_peptide_length \\
        -max_peptide_length $options.max_peptide_length \\
        -isotope_error_range $options.isotope_error_range \\
        -enzyme $options.enzyme \\
        -tryptic $options.num_enzyme_termini \\
        -precursor_mass_tolerence $options.prec_tol \\
        -precursor_error_unit $options.prec_tol_unit \\
        -fixed_modificaitons $options.fixed \\
        -variable_modifications $options.variable
        -max_mods $options.max_mods \\
        -debug $options.db_debug \\
        > ${mzml_file.baseName}_msgf.log

    echo \$(MSGFPlusAdapter --version 2>&1) > ${software}.version.txt
    """
}
