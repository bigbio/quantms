process INDIVIDUAL_FINAL_ANALYSIS {
    tag "$mzML.baseName"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'biocontainers/diann:v1.8.1_cv1' }"

    input:
    tuple val(meta), file(mzML), file(fasta), file(diann_log), file(library)

    output:
    path "*.quant", emit: diann_quant
    path "*_final_diann.log", emit: log
    path "versions.yml", emit: version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    mass_acc_ms1 = meta.precursor_mass_tolerance_unit == "ppm" ? meta.precursor_mass_tolerance : 5
    mass_acc_ms2 = meta.fragment_mass_tolerance_unit == "ppm" ? meta.fragment_mass_tolerance : 13
    scan_window = params.scan_window

    if (params.mass_acc_automatic | params.scan_window_automatic){
        mass_acc_ms2 = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 11 | tr -cd \"[0-9]\")"
        scan_window = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 19 | tr -cd \"[0-9]\")"
        mass_acc_ms1 = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 15 | tr -cd \"[0-9]\")"
    }

    """
    diann   --lib ${library} \\
            --f ${mzML} \\
            --fasta ${fasta} \\
            --threads ${task.cpus} \\
            --verbose $params.diann_debug \\
            --temp ./ \\
            --mass-acc \$(echo ${mass_acc_ms2}) \\
            --mass-acc-ms1 \$(echo ${mass_acc_ms1}) \\
            --window \$(echo ${scan_window}) \\
            --no-ifs-removal \\
            --no-main-report \\
            --relaxed-prot-inf \\
            --pg-level $params.pg_level \\
            $args \\
            |& tee ${mzML.baseName}_final_diann.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
