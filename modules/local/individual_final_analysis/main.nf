process INDIVIDUAL_FINAL_ANALYSIS {
    tag "$mzML.baseName"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'biocontainers/diann:v1.8.1_cv1' }"

    input:
    tuple file(mzML), file(diann_log), file(library)

    output:
    path "*.quant", emit: diann_quant
    path "*_final_diann.log", emit: log
    path "versions.yml", emit: version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    mass_acc = params.mass_acc_ms2
    scan_window = params.scan_window
    ms1_accuracy = params.mass_acc_ms1

    if (params.mass_acc_automatic | params.scan_window_automatic){
        mass_acc = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 11 | tr -cd \"[0-9]\")"
        scan_window = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 19 | tr -cd \"[0-9]\")"
        ms1_accuracy = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 15 | tr -cd \"[0-9]\")"
    }

    """
    diann   --lib ${library} \\
            --f ${mzML} \\
            --threads ${task.cpus} \\
            --verbose $params.diann_debug \\
            --temp ./ \\
            --mass-acc \$(echo ${mass_acc}) \\
            --mass-acc-ms1 \$(echo ${ms1_accuracy}) \\
            --window \$(echo ${scan_window}) \\
            --no-ifs-removal \\
            --no-main-report \\
            --no-prot-inf \\
            $args \\
            |& tee ${mzML.baseName}_final_diann.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
