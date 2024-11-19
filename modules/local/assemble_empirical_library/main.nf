process ASSEMBLE_EMPIRICAL_LIBRARY {
    tag "$meta.experiment_id"
    label 'process_low'
    label 'diann'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'docker.io/biocontainers/diann:v1.8.1_cv1' }"

    input:
    // In this step the real files are passed, and not the names
    path(ms_files)
    val(meta)
    path("quant/*")
    path(lib)

    output:
    path "empirical_library.*", emit: empirical_library
    path "assemble_empirical_library.log", emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    if (params.mass_acc_automatic) {
        mass_acc = '--quick-mass-acc --individual-mass-acc'
    } else if (meta['precursormasstoleranceunit'].toLowerCase().endsWith('ppm') && meta['fragmentmasstoleranceunit'].toLowerCase().endsWith('ppm')){
        mass_acc = "--mass-acc ${meta['fragmentmasstolerance']} --mass-acc-ms1 ${meta['precursormasstolerance']}"
    } else {
        mass_acc = '--quick-mass-acc --individual-mass-acc'
    }
    scan_window = params.scan_window_automatic ? '--individual-windows' : "--window $params.scan_window"

    """
    # Precursor Tolerance value was: ${meta['precursormasstolerance']}
    # Fragment Tolerance value was: ${meta['fragmentmasstolerance']}
    # Precursor Tolerance unit was: ${meta['precursormasstoleranceunit']}
    # Fragment Tolerance unit was: ${meta['fragmentmasstoleranceunit']}

    ls -lcth

    diann   --f ${(ms_files as List).join(' --f ')} \\
            --lib ${lib} \\
            --threads ${task.cpus} \\
            --out-lib empirical_library \\
            --verbose $params.diann_debug \\
            --rt-profiling \\
            --temp ./quant/ \\
            --use-quant \\
            ${mass_acc} \\
            ${scan_window} \\
            --gen-spec-lib \\
            $args \\
            2>&1 | tee assemble_empirical_library.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "\\d+\\.\\d+(\\.\\w+)*(\\.[\\d]+)?")
    END_VERSIONS
    """
}
