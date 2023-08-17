process DIANN_PRELIMINARY_ANALYSIS {
    tag "$mzML.baseName"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'biocontainers/diann:v1.8.1_cv1' }"

    input:
    tuple val(meta), path(mzML), path(predict_tsv)

    output:
    path "*.quant", emit: diann_quant
    tuple val(meta), path("*_diann.log"), emit: log
    path "versions.yml", emit: version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    // I am using here the ["key"] syntax, since the preprocessed meta makes
    // was evaluating to null when using the dot notation.
    mass_acc_ms1 = meta['precursormasstoleranceunit'].toLowerCase().endsWith('ppm') ? meta['precursormasstolerance'] : 5
    mass_acc_ms2 = meta['fragmentmasstoleranceunit'].toLowerCase().endsWith('ppm') ? meta['fragmentmasstolerance'] : 13

    if (params.mass_acc_automatic) {
        mass_acc = '--quick-mass-acc --individual-mass-acc'
    } else {
        mass_acc = '--mass-acc $mass_acc_ms2 --mass-acc-ms1 $mass_acc_ms1'
    }
    scan_window = params.scan_window_automatic ? '--individual-windows' : '--window $params.scan_window'
    time_corr_only = params.time_corr_only ? '--time-corr-only' : ''

    """
    # Precursor Tolerance value was: ${meta['precursormasstolerance']}
    # Fragment Tolerance value was: ${meta['fragmentmasstolerance']}
    # Precursor Tolerance unit was: ${meta['precursormasstoleranceunit']}
    # Fragment Tolerance unit was: ${meta['fragmentmasstoleranceunit']}

    diann   --lib ${predict_tsv} \\
            --f ${mzML} \\
            --threads ${task.cpus} \\
            --verbose $params.diann_debug \\
            ${scan_window} \\
            --temp ./ \\
            --min-corr $params.min_corr \\
            --corr-diff $params.corr_diff \\
            ${mass_acc} \\
            ${time_corr_only} \\
            $args \\
            2>&1 | tee ${mzML.baseName}_diann.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
