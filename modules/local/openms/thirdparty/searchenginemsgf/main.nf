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
    tuple val(mzml_id), val(fixed), val(variable), val(label), val(prec_tol), val(prec_tol_unit), val(frag_tol), val(frag_tol_unit), val(diss_meth), val(enzyme), file(mzml_file), file(database)

    output:
    tuple val(mzml_id), path("${mzml_file.baseName}_msgf.idXML"),  emit: id_files_msgf
    path "*.version.txt",   emit: version
    path "*.log",   emit: log

    script:
    // find a way to add MSGFPlus.jar dependence
    msgf_jar = ''
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        msgf_jar = "-executable \$(find /usr/local/share/msgf_plus-*/MSGFPlus.jar -maxdepth 0)"
    } else if (!params.enable_conda){
        msgf_jar = "-executable \$(find /usr/local/share/msgf_plus-*/MSGFPlus.jar -maxdepth 0)"
    }

    def software = getSoftwareName(task.process)

    if (enzyme == 'Trypsin') enzyme = 'Trypsin/P'
    else if (enzyme == 'Arg-C') enzyme = 'Arg-C/P'
    else if (enzyme == 'Asp-N') enzyme = 'Asp-N/B'
    else if (enzyme == 'Chymotrypsin') enzyme = 'Chymotrypsin'
    else if (enzyme == 'Lys-C') enzyme = 'Lys-C/P'

    if ((frag_tol.toDouble() < 50 && frag_tol_unit == "ppm") || (frag_tol.toDouble() < 0.1 && frag_tol_unit == "Da"))
    {
        inst = params.instrument ?: "high_res"
    } else {
        inst = params.instrument ?: "low_res"
    }

    """
    MSGFPlusAdapter \\
        -protocol $params.protocol \\
        -in ${mzml_file} \\
        -out ${mzml_file.baseName}_msgf.idXML \\
        ${msgf_jar} \\
        -threads $task.cpus \\
        -java_memory ${task.memory.toMega()} \\
        -database "${database}" \\
        -instrument ${inst} \\
        -matches_per_spec $params.num_hits \\
        -min_precursor_charge $params.min_precursor_charge \\
        -max_precursor_charge $params.max_precursor_charge \\
        -min_peptide_length $params.min_peptide_length \\
        -max_peptide_length $params.max_peptide_length \\
        -isotope_error_range $params.isotope_error_range \\
        -enzyme ${enzyme} \\
        -tryptic $params.num_enzyme_termini \\
        -precursor_mass_tolerance ${prec_tol} \\
        -precursor_error_units ${prec_tol_unit} \\
        -fixed_modifications ${fixed.tokenize(',').collect() { "'${it}'" }.join(" ") } \\
        -variable_modifications ${variable.tokenize(',').collect() { "'${it}'" }.join(" ") } \\
        -max_mods $params.max_mods \\
        -debug $params.db_debug \\
        $options.args \\
        > ${mzml_file.baseName}_msgf.log

    echo \$(MSGFPlusAdapter --version 2>&1) > ${software}.version.txt
    """
}
