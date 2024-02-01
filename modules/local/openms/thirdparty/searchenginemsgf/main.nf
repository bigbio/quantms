process SEARCHENGINEMSGF {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    conda "bioconda::openms-thirdparty=3.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:3.1.0--h9ee0642_1' :
        'biocontainers/openms-thirdparty:3.1.0--h9ee0642_1' }"

    input:
    tuple val(meta),  path(mzml_file), path(database)

    output:
    tuple val(meta), path("${mzml_file.baseName}_msgf.idXML"),  emit: id_files_msgf
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    // The OpenMS adapters need the actual jar file, not the executable/shell wrapper that (bio)conda creates
    msgf_jar = ''
    if ((workflow.containerEngine || (task.executor == "awsbatch")) && (task.container.indexOf("biocontainers") > -1 || task.container.indexOf("depot.galaxyproject.org") > -1)) {
        msgf_jar = "-executable \$(find /usr/local/share/msgf_plus-*/MSGFPlus.jar -maxdepth 0)"
    } else if (session.config.conda && session.config.conda.enabled) {
        msgf_jar = "-executable \$(find \$CONDA_PREFIX/share/msgf_plus-*/MSGFPlus.jar -maxdepth 0)"
    }

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

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
    max_missed_cleavages = "-max_missed_cleavages ${params.allowed_missed_cleavages}"
    if (meta.enzyme == "unspecific cleavage")
    {
        num_enzyme_termini = "none"
        max_missed_cleavages = ""
    }
    else if (params.num_enzyme_termini == "fully")
    {
        num_enzyme_termini = "full"
    }

    il_equiv = params.IL_equivalent ? "-PeptideIndexing:IL_equivalent" : ""

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
        ${max_missed_cleavages} \\
        -isotope_error_range $params.isotope_error_range \\
        -enzyme "${enzyme}" \\
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
        2>&1 | tee ${mzml_file.baseName}_msgf.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MSGFPlusAdapter: \$(MSGFPlusAdapter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
        msgf_plus: \$(msgf_plus 2>&1 | grep -E '^MS-GF\\+ Release.*')
    END_VERSIONS
    """
}
