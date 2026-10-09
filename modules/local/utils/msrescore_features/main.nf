process MSRESCORE_FEATURES {
    tag "$meta.mzml_id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/quantms-rescoring-sif:0.0.24' :
        'ghcr.io/bigbio/quantms-rescoring:0.0.24' }"

    input:
    tuple val(meta), path(id_files), path(mzml), path(model_weight)

    output:
    tuple val(meta), path("*ms2rescore.idparquet"), emit: idparquet
    tuple val(meta), path("*.html" )                               , optional:true, emit: html
    path "versions.yml"                                            , emit: versions
    path "*.log"                                                   , emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}_ms2rescore"

    // Only add ms2_model_dir if it's actually set and not empty
    // Handle cases where parameter might be empty string, null, boolean true, or whitespace
    // When --ms2features_model_dir is passed with no value, Nextflow may set it to boolean true
    if (params.ms2features_fine_tuning) {
        ms2_model_dir = '--ms2_model_dir ./'
    } else if (params.ms2features_model_dir && params.ms2features_model_dir != true){
        ms2_model_dir = "--ms2_model_dir ${model_weight}"
    } else {
        ms2_model_dir = "--ms2_model_dir ./"
    }

    // MS2PIP >=4.2 and AlphaPeptDeep both accept Da and ppm. Keep
    // the SDRF value and unit together; use config only if both are absent.
    def ms2_tolerance = meta['fragmentmasstolerance']
    def ms2_tolerance_unit = meta['fragmentmasstoleranceunit']
    if (ms2_tolerance == null && !ms2_tolerance_unit) {
        ms2_tolerance = params.ms2features_tolerance
        ms2_tolerance_unit = params.ms2features_tolerance_unit
    }
    if (ms2_tolerance == null || !ms2_tolerance_unit) {
        error "Fragment mass tolerance requires both a value and unit for ${meta.mzml_id}"
    }
    def unit = ms2_tolerance_unit.toString().trim().toLowerCase()
    if (unit in ['da', 'dalton', 'daltons']) {
        ms2_tolerance_unit = 'Da'
    } else if (unit == 'ppm') {
        ms2_tolerance_unit = 'ppm'
    } else {
        error "Unsupported fragment mass tolerance unit '${ms2_tolerance_unit}' for ${meta.mzml_id}"
    }

    if (params.decoy_string_position == "prefix") {
        decoy_pattern = "^${params.decoy_string}"
    } else {
        decoy_pattern = "${params.decoy_string}\$"
    }

    if (params.ms2features_best) {
        find_best_model = "--find_best_model"
    } else {
        find_best_model = ""
    }

    if (params.ms2features_force) {
        force_model = "--force_model"
    } else {
        force_model = ""
    }

    if (params.ms2features_modloss) {
        consider_modloss = "--consider_modloss"
    } else {
        consider_modloss = ""
    }

    if (params.ms2features_debug) {
        debug_log_level = "--log_level DEBUG"
    } else {
        debug_log_level = ""
    }

    """
    rescoring msrescore2feature \\
        --idparquet ${id_files.join(' --idparquet ')} \\
        --mzml $mzml \\
        --ms2_tolerance $ms2_tolerance \\
        --ms2_tolerance_unit $ms2_tolerance_unit \\
        --output ${mzml.baseName}_ms2rescore.idparquet \\
        ${ms2_model_dir} \\
        --processes $task.cpus \\
        ${find_best_model} \\
        ${force_model} \\
        ${consider_modloss} \\
        ${debug_log_level} \\
        $args \\
        2>&1 | tee ${mzml.baseName}_ms2rescore.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-rescoring: \$(rescoring --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
        ms2pip: \$(ms2pip --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
        deeplc: \$(deeplc --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
        MS2Rescore: \$(ms2rescore --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+' | head -n 1)
    END_VERSIONS
    """
}
