process ONSITE {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'onsite'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyonsite:0.0.2--pyhdfd78af_0' :
        'quay.io/biocontainers/pyonsite:0.0.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(mzml_file), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_*.idXML"), emit: ptm_in_id_onsite
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    // Algorithm selection: lucxor (default), ascore, or phosphors
    def algorithm = params.onsite_algorithm ?: 'lucxor'

    // Common parameters for all algorithms
    def fragment_tolerance = params.onsite_fragment_tolerance ?: '0.05'
    def compute_all_scores = params.onsite_compute_all_scores ? '--compute-all-scores' : ''

    // Set default value for add_decoys (can be overridden by setting params.onsite_add_decoys = false)
    def onsite_add_decoys = params.containsKey('onsite_add_decoys') ? params.onsite_add_decoys : true

    // Algorithm-specific parameters
    def fragment_unit = ''
    def add_decoys = onsite_add_decoys ? '--add-decoys' : ''
    def debug = params.onsite_debug ? '--debug' : ''

    // Build algorithm-specific command
    def algorithm_cmd = ''

    if (algorithm == 'ascore') {
        // AScore: uses -in, -id, -out, --fragment-mass-unit
        fragment_unit = params.onsite_fragment_unit ?: 'Da'
        def optional_flags = [add_decoys, compute_all_scores, debug].findAll { it }.join(' \\\n            ')
        algorithm_cmd = """
        onsite ascore \\
            -in ${mzml_file} \\
            -id ${id_file} \\
            -out ${id_file.baseName}_ascore.idXML \\
            --fragment-mass-tolerance ${fragment_tolerance} \\
            --fragment-mass-unit ${fragment_unit}${optional_flags ? ' \\\n            ' + optional_flags : ''}
        """
    } else if (algorithm == 'phosphors') {
        // PhosphoRS: uses -in, -id, -out, --fragment-mass-unit
        fragment_unit = params.onsite_fragment_unit ?: 'Da'
        def optional_flags = [add_decoys, compute_all_scores, debug].findAll { it }.join(' \\\n            ')
        algorithm_cmd = """
        onsite phosphors \\
            -in ${mzml_file} \\
            -id ${id_file} \\
            -out ${id_file.baseName}_phosphors.idXML \\
            --fragment-mass-tolerance ${fragment_tolerance} \\
            --fragment-mass-unit ${fragment_unit}${optional_flags ? ' \\\n            ' + optional_flags : ''}
        """
    } else if (algorithm == 'lucxor') {
        // LucXor: uses -in, -id, -out, --fragment-error-units (note: error-units not mass-unit)
        fragment_unit = params.onsite_fragment_error_units ?: 'Da'
        def fragment_method = params.onsite_fragment_method ?: 'CID'
        def min_mz = params.onsite_min_mz ?: '150.0'
        def max_charge = params.onsite_max_charge_state ?: '5'
        def max_peptide_len = params.onsite_max_peptide_length ?: '40'
        def max_num_perm = params.onsite_max_num_perm ?: '16384'
        def modeling_threshold = params.onsite_modeling_score_threshold ?: '0.95'
        def scoring_threshold = params.onsite_scoring_threshold ?: '0.0'
        def min_num_psms = params.onsite_min_num_psms_model ?: '5'
        def rt_tolerance = params.onsite_rt_tolerance ?: '0.01'
        def disable_split_by_charge = params.onsite_disable_split_by_charge ? '--disable-split-by-charge' : ''

        // Optional target modifications - default for LucXor includes decoy
        def target_mods = params.onsite_target_modifications ? "--target-modifications ${params.onsite_target_modifications}" : "--target-modifications 'Phospho(S),Phospho(T),Phospho(Y),PhosphoDecoy(A)'"
        def neutral_losses = params.onsite_neutral_losses ? "--neutral-losses ${params.onsite_neutral_losses}" : "--neutral-losses 'sty -H3PO4 -97.97690'"
        def decoy_mass = params.onsite_decoy_mass ? "--decoy-mass ${params.onsite_decoy_mass}" : "--decoy-mass 79.966331"
        def decoy_losses = params.onsite_decoy_neutral_losses ? "--decoy-neutral-losses ${params.onsite_decoy_neutral_losses}" : "--decoy-neutral-losses 'X -H3PO4 -97.97690'"

        def optional_flags = [disable_split_by_charge, compute_all_scores, debug].findAll { it }.join(' \\\n            ')
        algorithm_cmd = """
        onsite lucxor \\
            -in ${mzml_file} \\
            -id ${id_file} \\
            -out ${id_file.baseName}_lucxor.idXML \\
            --fragment-method ${fragment_method} \\
            --fragment-mass-tolerance ${fragment_tolerance} \\
            --fragment-error-units ${fragment_unit} \\
            --min-mz ${min_mz} \\
            ${target_mods} \\
            ${neutral_losses} \\
            ${decoy_mass} \\
            ${decoy_losses} \\
            --max-charge-state ${max_charge} \\
            --max-peptide-length ${max_peptide_len} \\
            --max-num-perm ${max_num_perm} \\
            --modeling-score-threshold ${modeling_threshold} \\
            --scoring-threshold ${scoring_threshold} \\
            --min-num-psms-model ${min_num_psms} \\
            --rt-tolerance ${rt_tolerance}${optional_flags ? ' \\\n            ' + optional_flags : ''}
        """
    } else {
        error "Unknown onsite algorithm: ${algorithm}. Supported algorithms: ascore, phosphors, lucxor"
    }

    """
    ${algorithm_cmd.trim()} 2>&1 | tee ${id_file.baseName}_${algorithm}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        onsite: \$(onsite --version 2>&1 | grep -oP 'version \\K[0-9.]+' || echo "unknown")
        algorithm: ${algorithm}
    END_VERSIONS
    """
}
