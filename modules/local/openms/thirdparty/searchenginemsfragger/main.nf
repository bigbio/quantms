process SEARCHENGINEMSFRAGGER {
    tag "$meta.id"
    label 'process_medium'

    container = 'tillenglert/oopenms_db_search:latest'

    input:
    tuple val(meta), file(mzml_file), file(database)

    output:
    tuple val(meta), path("${mzml_file.baseName}_msfragger.idXML"), emit: id_files_msfragger
    tuple val(meta), path("${mzml_file.baseName}.pepXML"), emit: pepxml_files_msfragger
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    enzyme_termini = params.num_enzyme_termini

    if (params.num_enzyme_termini == 0) {
        enzyme_termini = "non-enzymatic"
    }
    else if (params.num_enzyme_termini == 1) {
        enzyme_termini = "semi"
    }
    else if (params.num_enzyme_termini == 2) {
        enzyme_termini = "fully"
    }

    if (params.open_mod_search){
        precursor_mass_tolerance_upper = params.precursor_mass_tolerance_upper
        precursor_mass_tolerance_lower = -(params.precursor_mass_tolerance_lower)
        precursor_mass_tolerance_unit = "Da"
        isotope_error = "0"
    }
    else {
        precursor_mass_tolerance_upper = meta.precursormasstolerance
        precursor_mass_tolerance_lower = meta.precursormasstolerance
        precursor_mass_tolerance_unit = meta.precursormasstoleranceunit
        isotope_error = "0/1/2"
    }

    """
    MSFraggerAdapter \\
        -in \$PWD/${mzml_file} \\
        -out ${mzml_file.baseName}_msfragger.idXML \\
        -opt_out ${mzml_file.baseName}.pepXML \\
        -threads $task.cpus \\
        -license $params.msfragger_license \\
        -database \$PWD/${database} \\
        -executable "" \\
        -digest:allowed_missed_cleavage $params.allowed_missed_cleavages \\
        -digest:min_length $params.min_peptide_length \\
        -digest:max_length $params.max_peptide_length \\
        -digest:num_enzyme_termini ${enzyme_termini} \\
        -digest:search_enzyme_name $meta.enzyme \\
        -tolerance:isotope_error $isotope_error \\
        -statmod:unimod ${meta.fixedmodifications.tokenize(',').collect { "'$it'" }.join(" ") } \\
        -varmod:unimod ${meta.variablemodifications.tokenize(',').collect { "'$it'" }.join(" ") } \\
        -varmod:max_variable_mods_per_peptide $params.max_mods \\
        -tolerance:precursor_mass_tolerance_lower $precursor_mass_tolerance_lower \\
        -tolerance:precursor_mass_tolerance_upper $precursor_mass_tolerance_upper \\
        -tolerance:precursor_mass_unit $precursor_mass_tolerance_unit \\
        -tolerance:fragment_mass_tolerance $meta.fragmentmasstolerance \\
        -tolerance:fragment_mass_unit ${params.fragment_mass_tolerance_unit} \\
        -PeptideIndexing:decoy_string ${params.decoy_string} \\
        -debug $params.db_debug \\
        -force \\
        $args \\
        |& tee ${mzml_file.baseName}_msfragger.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MSFraggerAdapter: \$(MSFraggerAdapter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | sed 's/, Revision:.*//g')
        MSFragger: \$(java -jar \$MSFRAGGER_PATH --version 2>&1 | grep -E "MSFragger version.*" | sed 's/MSFragger version MSFragger-//g')
    END_VERSIONS
    """
}