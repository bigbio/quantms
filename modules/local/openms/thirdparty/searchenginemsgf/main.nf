process SEARCHENGINEMSGF {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::openms-thirdparty=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

    input:
    tuple val(meta),  file(mzml_file), file(database)

    output:
    tuple val(meta), path("${mzml_file.baseName}_msgf.idXML"),  emit: id_files_msgf
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    // The OpenMS adapters need the actuall jar file, not the executable/shell wrapper that (bio)conda creates
    msgf_jar = ''
    if (workflow.containerEngine || (task.executor == "awsbatch")) {
        msgf_jar = "-executable \$(find /usr/local/share/msgf_plus-*/MSGFPlus.jar -maxdepth 0)"
    } else if (params.enable_conda) {
        msgf_jar = "-executable \$(find \$CONDA_PREFIX/share/msgf_plus-*/MSGFPlus.jar -maxdepth 0)"
    }

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    enzyme = meta.enzyme
    if (meta.enzyme == 'Trypsin') enzyme = 'Trypsin/P'
    else if (meta.enzyme == 'Arg-C') enzyme = 'Arg-C/P'
    else if (meta.enzyme == 'Asp-N') enzyme = 'Asp-N/B'
    else if (meta.enzyme == 'Chymotrypsin') enzyme = 'Chymotrypsin'
    else if (meta.enzyme == 'Lys-C') enzyme = 'Lys-C/P'

    if (enzyme.toLowerCase() == "unspecific cleavage") {
        msgf_num_enzyme_termini = "non"
    } else {
        msgf_num_enzyme_termini = params.num_enzyme_termini
    }

    if ((meta.fragmentmasstolerance.toDouble() < 50 && meta.fragmentmasstoleranceunit == "ppm") || (meta.fragmentmasstolerance.toDouble() < 0.1 && meta.fragmentmasstoleranceunit == "Da"))
    {
        inst = params.instrument ?: "high_res"
    } else {
        inst = params.instrument ?: "low_res"
    }

    num_enzyme_termini = ""
    if (meta.enzyme == "unspecific cleavage")
    {
        num_enzyme_termini = "none"
    }
    else if (params.num_enzyme_termini == "fully")
    {
        num_enzyme_termini = "full"
    }

    il_equiv = params.IL_equivalent ? "-PeptideIndexing:IL_equivalent" : ""

    """
    ls -la \$CONDA_PREFIX
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
        -tryptic ${msgf_num_enzyme_termini} \\
        -precursor_mass_tolerance $meta.precursormasstolerance \\
        -precursor_error_units $meta.precursormasstoleranceunit \\
        -fixed_modifications ${meta.fixedmodifications.tokenize(',').collect() { "'${it}'" }.join(" ") } \\
        -variable_modifications ${meta.variablemodifications.tokenize(',').collect() { "'${it}'" }.join(" ") } \\
        -max_mods $params.max_mods \\
        ${il_equiv} \\
        -PeptideIndexing:unmatched_action ${params.unmatched_action} \\
        -debug $params.db_debug \\
        $args \\
        |& tee ${mzml_file.baseName}_msgf.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MSGFPlusAdapter: \$(MSGFPlusAdapter 2>&1 | grep -E '^Version(.*)' | sed "s/Version: //g")
        msgf_plus: \$(msgf_plus 2>&1 | grep -E '^MS-GF\\+ Release.*')
    END_VERSIONS
    """
}
