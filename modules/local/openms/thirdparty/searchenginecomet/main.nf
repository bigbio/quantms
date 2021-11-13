// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SEARCHENGINECOMET {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.6.0--0"
    } else {
        container "quay.io/biocontainers/openms-thirdparty:2.6.0--0"
    }

    input:
    tuple val(meta), file(mzml_file), file(database)

    output:
    tuple val(meta), path("${mzml_file.baseName}_comet.idXML"),  emit: id_files_comet
    path "*.version.txt",   emit: version
    path "*.log",   emit: log

    script:
    def software = getSoftwareName(task.process)

    if (meta.fragmentmasstoleranceunit == "ppm") {
        // Note: This uses an arbitrary rule to decide if it was hi-res or low-res
        // and uses Comet's defaults for bin size, in case unsupported unit "ppm" was given.
        if (meta.fragmentmasstolerance.toDouble() < 50) {
            bin_tol = "0.015"
            bin_offset = "0.0"
            inst = params.instrument ?: "high_res"
        } else {
            bin_tol = "0.50025"
            bin_offset = "0.4"
            inst = params.instrument ?: "low_res"
        }
        log.warn "The chosen search engine Comet does not support ppm fragment tolerances. We guessed a " + inst +
            " instrument and set the fragment_bin_tolerance to " + bin_tol
    } else {
        // TODO expose the fragment_bin_offset parameter of comet
        bin_tol = meta.fragmentmasstolerance.toDouble()
        bin_offset = meta.fragmentmasstolerance <= 0.05 ? "0.0" : "0.4"
        if (!params.instrument)
        {
            inst = meta.fragmentmasstolerance <= 0.05 ? "high_res" : "low_res"
        } else {
            inst = params.instrument
        }
    }

    // for consensusID the cutting rules need to be the same. So we adapt to the loosest rules from MSGF
    // TODO find another solution. In ProteomicsLFQ we re-run PeptideIndexer (remove??) and if we
    // e.g. add XTandem, after running ConsensusID it will lose the auto-detection ability for the
    // XTandem specific rules.
    if (params.search_engines.contains("msgf")){
        if (meta.enzyme == "Trypsin") enzyme = "Trypsin/P"
        else if (meta.enzyme == "Arg-C") enzyme = "Arg-C/P"
        else if (meta.enzyme == "Asp-N") enzyme = "Arg-N/B"
        else if (meta.enzyme == "Chymotrypsin") enzyme = "Chymotrypsin/P"
        else if (meta.enzyme == "Lys-C") enzyme = "Lys-C/P"
    }

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
        -enzyme ${enzyme} \\
        -precursor_charge $params.min_precursor_charge:$params.max_precursor_charge \\
        -fixed_modifications ${meta.fixedmodifications.tokenize(',').collect { "'$it'" }.join(" ") } \\
        -variable_modifications ${meta.variablemodifications.tokenize(',').collect { "'$it'" }.join(" ") } \\
        -max_variable_mods_in_peptide $params.max_mods \\
        -precursor_mass_tolerance $meta.precursormasstolerance \\
        -precursor_error_units $meta.precursormasstoleranceunit \\
        -fragment_mass_tolerance ${bin_tol} \\
        -fragment_bin_offset ${bin_offset} \\
        -debug $params.db_debug \\
        -force \\
        $options.args \\
        > ${mzml_file.baseName}_comet.log

    echo \$(CometAdapter 2>&1) > ${software}.version.txt
    """
}
