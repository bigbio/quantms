process MSRESCORE_FINE_TUNING {
    tag "$meta.mzml_id"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/quantms-rescoring-sif:0.0.14' :
        'ghcr.io/bigbio/quantms-rescoring:0.0.14' }"

    input:
    tuple val(meta), path(idxml), path(mzml), path(ms2_model_dir)

    output:
    path "retained_ms2.pth" , emit: model_weight
    path "versions.yml"     , emit: versions
    path "*.log"            , emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}_ms2rescore"

    // Initialize tolerance variables
    def ms2_tolerance = null
    def ms2_tolerance_unit = null

    // ms2pip only supports Da unit, but alphapeptdeep supports both Da and ppm
    ms2_tolerance = meta['fragmentmasstolerance']
    ms2_tolerance_unit = meta['fragmentmasstoleranceunit']

    if (params.force_transfer_learning) {
        force_transfer_learning = "--force_transfer_learning"
    } else {
        force_transfer_learning = ""
    }

    if (params.ms2features_modloss) {
        consider_modloss = "--consider_modloss"
    } else {
        consider_modloss = ""
    }

    """
    rescoring transfer_learning \\
        --idxml ./ \\
        --mzml ./ \\
        --save_model_dir ./ \\
        --ms2_tolerance $ms2_tolerance \\
        --ms2_tolerance_unit $ms2_tolerance_unit \\
        --processes $task.cpus \\
        --ms2_model_dir ${ms2_model_dir} \\
        --calibration_set_size ${params.ms2features_calibration} \\
        --epoch_to_train_ms2 ${params.epoch_to_train_ms2} \\
        --transfer_learning_test_ratio ${params.transfer_learning_test_ratio} \\
        ${force_transfer_learning} \\
        ${consider_modloss} \\
        $args \\
        2>&1 | tee ${idxml.baseName}_fine_tuning.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-rescoring: \$(rescoring --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
        ms2pip: \$(ms2pip --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
        deeplc: \$(deeplc --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
        MS2Rescore: \$(ms2rescore --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+' | head -n 1)
    END_VERSIONS
    """
}
