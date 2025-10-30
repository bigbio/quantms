process MSRESCORE_FEATURES {
    tag "$meta.mzml_id"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/quantms-rescoring-sif:0.0.12' :
        'ghcr.io/bigbio/quantms-rescoring:0.0.12' }"

    // userEmulation settings when docker is specified
    containerOptions = (workflow.containerEngine == 'docker') ? '-u $(id -u) -e "HOME=${HOME}" -v /etc/passwd:/etc/passwd:ro -v /etc/shadow:/etc/shadow:ro -v /etc/group:/etc/group:ro -v $HOME:$HOME' : ''

    input:
    tuple val(meta), path(idxml), path(mzml)

    output:
    tuple val(meta), path("*ms2rescore.idXML") , emit: idxml
    tuple val(meta), path("*.html" )           , optional:true, emit: html
    path "versions.yml"                        , emit: versions
    path "*.log"                               , emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}_ms2rescore"

    def ms2_model_dir = params.ms2features_model_dir ? "--ms2_model_dir ${params.ms2features_model_dir}" : ""

    // Determine if using ms2pip or alphapeptdeep based on ms2features_generators
    def using_ms2pip = params.ms2features_generators.toLowerCase().contains('ms2pip')
    def using_alphapeptdeep = params.ms2features_generators.toLowerCase().contains('alphapeptdeep')

    // Initialize tolerance variables
    def ms2_tolerance = null
    def ms2_tolerance_unit = null

    // ms2pip only supports Da unit, but alphapeptdeep supports both Da and ppm
    ms2_tolerance = meta['fragmentmasstolerance']
    ms2_tolerance_unit = meta['fragmentmasstoleranceunit']
    if (using_ms2pip) {
        // ms2pip only supports Da unit
        ms2_tolerance_unit = 'Da'
        ms2_tolerance = params.ms2features_tolerance
        if (meta['fragmentmasstoleranceunit'].toLowerCase().endsWith('da')) {
            ms2_tolerance = meta['fragmentmasstolerance']
        } else if (params.ms2features_tolerance_unit == 'ppm') {
            log.info "Warning: MS2pip only supports Da unit. Using default from config!"
            ms2_tolerance = 0.05
        } else {
            log.info "Warning: MS2pip only supports Da unit. Using default from config!"
        }
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
        --idxml $idxml \\
        --mzml $mzml \\
        --ms2_tolerance $ms2_tolerance \\
        --ms2_tolerance_unit $ms2_tolerance_unit \\
        --output ${idxml.baseName}_ms2rescore.idXML \\
        ${ms2_model_dir} \\
        --processes $task.cpus \\
        ${find_best_model} \\
        ${force_model} \\
        ${consider_modloss} \\
        ${debug_log_level} \\
        $args \\
        2>&1 | tee ${idxml.baseName}_ms2rescore.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-rescoring: \$(rescoring --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
        ms2pip: \$(ms2pip --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
        deeplc: \$(deeplc --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
        MS2Rescore: \$(ms2rescore --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+' | head -n 1)
    END_VERSIONS
    """
}
