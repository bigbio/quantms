process DIANN_PRELIMINARY_ANALYSIS {
    tag "$ms_file.baseName"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'docker.io/biocontainers/diann:v1.8.1_cv1' }"

    if (params.diann_version == "1.9.beta.1") {
        container 'https://ftp.pride.ebi.ac.uk/pub/databases/pride/resources/tools/ghcr.io-bigbio-diann-1.9.1dev.sif'
    }

    input:
    tuple val(meta), path(ms_file), path(predict_library)

    output:
    path "*.quant", emit: diann_quant
    tuple val(meta), path("*_diann.log"), emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    // I am using here the ["key"] syntax, since the preprocessed meta makes
    // was evaluating to null when using the dot notation.

    if (params.mass_acc_automatic) {
        mass_acc = '--quick-mass-acc --individual-mass-acc'
    } else if (meta['precursormasstoleranceunit'].toLowerCase().endsWith('ppm') && meta['fragmentmasstoleranceunit'].toLowerCase().endsWith('ppm')){
        mass_acc = "--mass-acc ${meta['fragmentmasstolerance']} --mass-acc-ms1 ${meta['precursormasstolerance']}"
    } else {
        log.info "Warning: DIA-NN only supports ppm unit tolerance for MS1 and MS2. Falling back to `mass_acc_automatic`=`true` to automatically determine the tolerance by DIA-NN!"
        mass_acc = '--quick-mass-acc --individual-mass-acc'
    }

    // Notes: Use double quotes for params, so that it is escaped in the shell.
    scan_window = params.scan_window_automatic ? '--individual-windows' : "--window $params.scan_window"
    time_corr_only = params.time_corr_only ? '--time-corr-only' : ''

    """
    # Precursor Tolerance value was: ${meta['precursormasstolerance']}
    # Fragment Tolerance value was: ${meta['fragmentmasstolerance']}
    # Precursor Tolerance unit was: ${meta['precursormasstoleranceunit']}
    # Fragment Tolerance unit was: ${meta['fragmentmasstoleranceunit']}

    # Final mass accuracy is '${mass_acc}'

    diann   --lib ${predict_library} \\
            --f ${ms_file} \\
            --threads ${task.cpus} \\
            --verbose $params.diann_debug \\
            ${scan_window} \\
            --temp ./ \\
            --min-corr $params.min_corr \\
            --corr-diff $params.corr_diff \\
            ${mass_acc} \\
            ${time_corr_only} \\
            $args \\
            2>&1 | tee ${ms_file.baseName}_diann.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "\\d+\\.\\d+(\\.\\w+)*(\\.[\\d]+)?")
    END_VERSIONS
    """
}
