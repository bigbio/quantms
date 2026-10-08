process PROSE {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2026.10.04' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2026.10.04' }"

    input:
    tuple val(meta), path(ms_file), path(database)

    output:
    tuple val(meta), path("${ms_file.baseName}_prose.idparquet"), emit: id_files_prose
    path "${ms_file.baseName}_prose_summary.yaml", emit: summary
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    // The in-process Thermo RAW reader of the pinned OpenMS image cannot open .raw files through
    // symlinks (as staged by Nextflow), so vendor files are passed by their resolved path.
    // The file name stays the same, so run names still match the experimental design.
    def vendorPath = { f -> f.name ==~ /(?i).*\.(raw|d)/ ? "\$(readlink -f ${f})" : "${f}" }
    // Bruker .d m/z values are only correct with the Bruker TDF SDK (open-source approximation: up to ~37 ppm off)
    def has_dotd = [ms_file].any { f -> f.name ==~ /(?i).*\.d/ }

    // ProSE requires enzyme specificity for both termini; 'unspecific cleavage' maps to no specificity.
    def specificity = [fully: 'full', semi: 'semi', none: 'none'][params.num_enzyme_termini]
    if (meta.enzyme == 'unspecific cleavage') {
        specificity = 'none'
    }
    if (specificity == null) {
        error("ProSE: unsupported --num_enzyme_termini '${params.num_enzyme_termini}' (valid: fully, semi, none)")
    }

    def iso_range = (params.isotope_error_range ?: '0,1').tokenize(',')
    def precursor_tol = meta.precursormasstolerance
    def mods_fixed = meta.fixedmodifications.tokenize(',').collect { mod -> "'$mod'" }.join(' ')
    def mods_var = meta.variablemodifications.tokenize(',').collect { mod -> "'$mod'" }.join(' ')
    // Summary line ProSE logs after adding PeptDeep predicted features (OpenMS/OpenMS#9975)
    def peptdeep_marker = '\\[PeptDeepRescoring\\] Predicted features added: [1-9][0-9]* / [0-9]+ PSMs'

    """
    # ProSE rescoring with Percolator is mandatory in quantms: downstream steps need Percolator PEPs.
    ProSE \\
        -in ${vendorPath.call(ms_file)} \\
        -database "${database}" \\
        -out_idxml ${ms_file.baseName}_prose.idXML \\
        -summary_out ${ms_file.baseName}_prose_summary.yaml \\
        -percolator_executable percolator \\
        -threads $task.cpus \\
        -Search:enzyme "${meta.enzyme}" \\
        -Search:peptide:enzyme_specificity ${specificity} \\
        -Search:peptide:missed_cleavages $params.allowed_missed_cleavages \\
        -Search:peptide:min_size $params.min_peptide_length \\
        -Search:peptide:max_size $params.max_peptide_length \\
        -Search:peptide:clip_nterm_methionine ${params.met_excision ? 'true' : 'false'} \\
        -Search:precursor:mass_tolerance_lower ${precursor_tol} \\
        -Search:precursor:mass_tolerance_upper ${precursor_tol} \\
        -Search:precursor:mass_tolerance_unit ${meta.precursormasstoleranceunit} \\
        -Search:precursor:min_charge $params.min_precursor_charge \\
        -Search:precursor:max_charge $params.max_precursor_charge \\
        -Search:precursor:isotope_error_min ${iso_range[0]} \\
        -Search:precursor:isotope_error_max ${iso_range[1]} \\
        -Search:fragment:mass_tolerance ${meta.fragmentmasstolerance} \\
        -Search:fragment:mass_tolerance_unit ${meta.fragmentmasstoleranceunit} \\
        -Search:modifications:fixed ${mods_fixed} \\
        -Search:modifications:variable ${mods_var} \\
        -Search:modifications:variable_max_per_peptide $params.max_mods \\
        -Search:report:top_hits $params.num_hits \\
        -Search:decoys auto \\
        -Search:FDR:PSM 0 \\
        -Search:peptdeep:enable ${params.prose_peptdeep ? 'true' : 'false'} \\
        -Search:peptdeep:instrument ${params.prose_peptdeep_instrument} \\
        -debug $params.db_debug \\
        $args \\
        2>&1 | tee ${ms_file.baseName}_prose.log

    if [ "${has_dotd}" = "true" ] && { ! grep -qF 'TIMS calibration: Bruker SDK (m/z + 1/K0)' ${ms_file.baseName}_prose.log || grep -F 'TIMS calibration:' ${ms_file.baseName}_prose.log | grep -vqF 'Bruker SDK (m/z'; }; then
        echo "ERROR: Bruker .d input was not read with the Bruker TDF SDK m/z calibration (needs the amd64 OpenMS image with libtimsdata). See ${ms_file.baseName}_prose.log." >&2
        exit 1
    fi

    # Fail loudly instead of silently continuing with unrescored or self-generated-decoy results.
    if ! grep -q 'decoy_mode: "external"' ${ms_file.baseName}_prose_summary.yaml; then
        echo "ERROR: ProSE did not use the target-decoy database provided by quantms (see decoy_mode in ${ms_file.baseName}_prose_summary.yaml)." >&2
        exit 1
    fi
    if ! grep -Eq 'Percolator +: rescored 1 / 1 file' ${ms_file.baseName}_prose.log; then
        echo "ERROR: ProSE did not rescore ${ms_file} with Percolator (too few PSMs or decoys?). See ${ms_file.baseName}_prose.log." >&2
        exit 1
    fi
    if [ "${params.prose_peptdeep}" = "true" ] && ! grep -Eq '${peptdeep_marker}' ${ms_file.baseName}_prose.log; then
        echo "ERROR: ProSE did not add PeptDeep predicted features for ${ms_file} (OpenMS without ONNX support or missing models?). See ${ms_file.baseName}_prose.log; use --prose_peptdeep false to rescore without predicted features." >&2
        exit 1
    fi

    IDFileConverter \\
        -in ${ms_file.baseName}_prose.idXML \\
        -out ${ms_file.baseName}_prose.idparquet \\
        -threads $task.cpus \\
        2>&1 | tee ${ms_file.baseName}_prose_idconvert.log
    rm ${ms_file.baseName}_prose.idXML

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ProSE: \$(ProSE 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
        percolator: \$(percolator -h 2>&1 | grep -E '^Percolator version(.*)' | sed 's/Percolator version //g')
    END_VERSIONS
    """

}
