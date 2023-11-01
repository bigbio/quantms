process INDIVIDUAL_FINAL_ANALYSIS {
    tag "$ms_file.baseName"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'docker.io/biocontainers/diann:v1.8.1_cv1' }"

    input:
    tuple val(meta), path(ms_file), path(fasta), path(diann_log), path(library)

    output:
    path "*.quant", emit: diann_quant
    path "*_final_diann.log", emit: log
    path "versions.yml", emit: version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    scan_window = params.scan_window

    if (params.mass_acc_automatic | params.scan_window_automatic) {
        mass_acc_ms2 = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 11 | tr -cd \"[0-9]\")"
        scan_window = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 19 | tr -cd \"[0-9]\")"
        mass_acc_ms1 = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 15 | tr -cd \"[0-9]\")"
    } else if (meta['precursormasstoleranceunit'].toLowerCase().endsWith('ppm') && meta['fragmentmasstoleranceunit'].toLowerCase().endsWith('ppm')) {
        mass_acc_ms1 = meta["precursormasstolerance"]
        mass_acc_ms2 = meta["fragmentmasstolerance"]
    } else {
        mass_acc_ms2 = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 11 | tr -cd \"[0-9]\")"
        scan_window = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 19 | tr -cd \"[0-9]\")"
        mass_acc_ms1 = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 15 | tr -cd \"[0-9]\")"
    }

    """
    diann   --lib ${library} \\
            --f ${ms_file} \\
            --fasta ${fasta} \\
            --threads ${task.cpus} \\
            --verbose $params.diann_debug \\
            --temp ./ \\
            --mass-acc ${mass_acc_ms2} \\
            --mass-acc-ms1 ${mass_acc_ms1} \\
            --window ${scan_window} \\
            --no-ifs-removal \\
            --no-main-report \\
            --relaxed-prot-inf \\
            --pg-level $params.pg_level \\
            $args \\
            2>&1 | tee ${ms_file.baseName}_final_diann.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
