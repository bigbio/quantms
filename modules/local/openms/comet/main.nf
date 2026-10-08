def comet_binning(meta, width, offset, instrument) {
    def unit = meta.fragmentmasstoleranceunit?.toString()?.trim()?.toLowerCase()
    if (!(unit in ['da', 'ppm'])) {
        error "Unsupported Comet fragment tolerance unit '${meta.fragmentmasstoleranceunit}' for ${meta.mzml_id}"
    }
    def explicit = width != null || offset != null
    if (explicit && (width == null || offset == null || !instrument)) {
        error "Comet explicit binning requires comet_fragment_bin_tol, comet_fragment_bin_offset and comet_instrument for ${meta.mzml_id}"
    }
    if (!explicit && unit == 'ppm') {
        error "Comet cannot derive a fixed bin width from ppm for ${meta.mzml_id}; set comet_fragment_bin_tol, comet_fragment_bin_offset and comet_instrument explicitly (or per-run ext overrides)"
    }
    def number = { value, name ->
        def result
        try {
            result = Double.parseDouble(value?.toString() ?: '')
        } catch (NumberFormatException exception) {
            error "Comet ${name} must be numeric for ${meta.mzml_id}: ${exception.message}"
        }
        if (!Double.isFinite(result)) {
            error "Comet ${name} must be finite for ${meta.mzml_id}"
        }
        return result
    }
    // OpenMS accepts half the native Comet bin width. Preserve the legacy Da path.
    def binWidth = explicit ? number.call(width, 'bin width') : 2 * number.call(meta.fragmentmasstolerance, 'fragment tolerance')
    def binOffset = explicit ? number.call(offset, 'bin offset') : (binWidth <= 0.1 ? 0.0 : 0.4)
    def mode = instrument ?: (binWidth <= 0.1 ? 'high_res' : 'low_res')
    if (binWidth < 0.01) {
        error "Comet bin width must be at least 0.01 Da for ${meta.mzml_id}"
    }
    if (binOffset < 0 || binOffset > 1) {
        error "Comet bin offset must be between 0 and 1 for ${meta.mzml_id}"
    }
    if (!(mode in ['high_res', 'low_res'])) {
        error "Comet instrument must be high_res or low_res for ${meta.mzml_id}"
    }
    return [width: binWidth, tolerance: binWidth / 2, offset: binOffset, instrument: mode, explicit: explicit]
}

process COMET {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2026.10.04' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2026.10.04' }"

    input:
    tuple val(meta), path(mzml_file), path(database)

    output:
    tuple val(meta), path("${mzml_file.baseName}_comet.idparquet"),  emit: id_files_comet
    path "versions.yml",   emit: versions
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''

    def width = task.ext.comet_fragment_bin_tol != null ? task.ext.comet_fragment_bin_tol : params.comet_fragment_bin_tol
    def offset = task.ext.comet_fragment_bin_offset != null ? task.ext.comet_fragment_bin_offset : params.comet_fragment_bin_offset
    def instrument = task.ext.comet_instrument != null ? task.ext.comet_instrument : (params.comet_instrument != null ? params.comet_instrument : params.instrument)
    def binning = comet_binning(meta, width, offset, instrument)
    def bin_tol = binning.tolerance
    def bin_offset = binning.offset
    def inst = binning.instrument
    log.debug "Comet ${meta.mzml_id}: input fragment tolerance=${meta.fragmentmasstolerance} ${meta.fragmentmasstoleranceunit}; " +
        "fragment_bin_tol=${binning.width} Da (full width), adapter_fragment_mass_tolerance=${bin_tol} Da, " +
        "fragment_bin_offset=${bin_offset}, instrument=${inst}, source=${binning.explicit ? 'explicit Comet settings' : 'input Da'}"

    def isoSlashComet = "0/1"
    if (params.isotope_error_range) {
        def isoRangeComet = params.isotope_error_range.split(",")
        def range = (isoRangeComet[0].toInteger()..isoRangeComet[1].toInteger()-1).collect { v -> v.toString() }
        range.add(isoRangeComet[1])
        isoSlashComet = range.join("/")
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

    met_excision = params.met_excision ? "-clip_nterm_methionine true" : ""

    """
    CometAdapter \\
        -in ${mzml_file} \\
        -out ${mzml_file.baseName}_comet.idparquet \\
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
        -fixed_modifications ${meta.fixedmodifications.tokenize(',').collect { mod -> "'$mod'" }.join(" ") } \\
        -variable_modifications ${meta.variablemodifications.tokenize(',').collect { mod -> "'$mod'" }.join(" ") } \\
        -max_variable_mods_in_peptide $params.max_mods \\
        -precursor_mass_tolerance $meta.precursormasstolerance \\
        -precursor_error_units $meta.precursormasstoleranceunit \\
        -fragment_mass_tolerance ${bin_tol} \\
        -fragment_bin_offset ${bin_offset} \\
        -minimum_peaks $params.min_peaks \\
        ${met_excision} \\
        ${il_equiv} \\
        -PeptideIndexing:unmatched_action ${params.unmatched_action} \\
        -debug $params.db_debug \\
        -force \\
        $args \\
        2>&1 | tee ${mzml_file.baseName}_comet.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CometAdapter: \$(CometAdapter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
        Comet: \$(/opt/OpenMS/thirdparty/Comet/comet.exe 2>&1 | grep -m1 -E "^[[:space:]]*Comet version.*" | sed 's/^[[:space:]]*Comet version //g' | sed 's/"//g')
    END_VERSIONS
    """
}
