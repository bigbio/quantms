process SEARCHENGINECOMET {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    conda "bioconda::openms-thirdparty=3.2.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:3.2.0--h9ee0642_4' :
        'biocontainers/openms-thirdparty:3.2.0--h9ee0642_4' }"

    input:
    tuple val(meta), path(mzml_file), path(database)

    output:
    tuple val(meta), path("${mzml_file.baseName}_comet.idXML"),  emit: id_files_comet
    path "versions.yml",   emit: versions
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    if (meta.fragmentmasstoleranceunit == "ppm") {
        // Note: This uses an arbitrary rule to decide if it was hi-res or low-res
        // and uses Comet's defaults for bin size, in case unsupported unit "ppm" was given.
        if (meta.fragmentmasstolerance.toDouble() < 50) {
            bin_tol = 0.015
            bin_offset = 0.0
            inst = params.instrument ?: "high_res"
        } else {
            bin_tol = 0.50025
            bin_offset = 0.4
            inst = params.instrument ?: "low_res"
        }
        log.warn "The chosen search engine Comet does not support ppm fragment tolerances. We guessed a " + inst +
            " instrument and set the fragment_bin_tolerance to " + bin_tol
    } else {
        // TODO expose the fragment_bin_offset parameter of comet
        bin_tol = meta.fragmentmasstolerance.toDouble()
        bin_offset = bin_tol <= 0.05 ? 0.0 : 0.4
        if (!params.instrument)
        {
            inst = bin_tol <= 0.05 ? "high_res" : "low_res"
        } else {
            inst = params.instrument
        }
    }

    def isoSlashComet = "0/1"
    if (params.isotope_error_range) {
        def isoRangeComet = params.isotope_error_range.split(",")
        isoSlashComet = ""
        for (c in isoRangeComet[0].toInteger()..isoRangeComet[1].toInteger()-1) {
            isoSlashComet += c + "/"
        }
        isoSlashComet += isoRangeComet[1]
    }
    // for consensusID the cutting rules need to be the same. So we adapt to the loosest rules from MSGF
    // TODO find another solution. In ProteomicsLFQ we re-run PeptideIndexer (remove??) and if we
    // e.g. add XTandem, after running ConsensusID it will lose the auto-detection ability for the
    // XTandem specific rules.
    enzyme = meta.enzyme
    if (params.search_engines.contains("msgf")){
        if (meta.enzyme == "Trypsin") enzyme = "Trypsin/P"
        else if (meta.enzyme == "Arg-C") enzyme = "Arg-C/P"
        else if (meta.enzyme == "Asp-N") enzyme = "Arg-N/B"
        else if (meta.enzyme == "Chymotrypsin") enzyme = "Chymotrypsin/P"
        else if (meta.enzyme == "Lys-C") enzyme = "Lys-C/P"
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
    CometAdapter \\
        -in ${mzml_file} \\
        -out ${mzml_file.baseName}_comet.idXML \\
        -threads $task.cpus \\
        -database "${database}" \\
        -instrument ${inst} \\
        -missed_cleavages $params.allowed_missed_cleavages \\
        -min_peptide_length $params.min_peptide_length \\
        -max_peptide_length $params.max_peptide_length \\
        -num_hits $params.num_hits \\
        -num_enzyme_termini $params.num_enzyme_termini \\
        -enzyme "${enzyme}" \\
        -isotope_error ${isoSlashComet} \\
        -precursor_charge $params.min_precursor_charge:$params.max_precursor_charge \\
        -fixed_modifications ${meta.fixedmodifications.tokenize(',').collect { "'$it'" }.join(" ") } \\
        -variable_modifications ${meta.variablemodifications.tokenize(',').collect { "'$it'" }.join(" ") } \\
        -max_variable_mods_in_peptide $params.max_mods \\
        -precursor_mass_tolerance $meta.precursormasstolerance \\
        -precursor_error_units $meta.precursormasstoleranceunit \\
        -fragment_mass_tolerance ${bin_tol} \\
        -fragment_bin_offset ${bin_offset} \\
        -minimum_peaks $params.min_peaks \\
        ${il_equiv} \\
        -PeptideIndexing:unmatched_action ${params.unmatched_action} \\
        -debug $params.db_debug \\
        -force \\
        $args \\
        2>&1 | tee ${mzml_file.baseName}_comet.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CometAdapter: \$(CometAdapter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
        Comet: \$(comet 2>&1 | grep -E "Comet version.*" | sed 's/ Comet version //g' | sed 's/"//g')
    END_VERSIONS
    """
}
