process INDIVIDUAL_FINAL_ANALYSIS {
    tag "$mzML.baseName"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'biocontainers/diann:v1.8.1_cv1' }"

    input:
    tuple file(mzML), file(diann_log), file(library), file(diann_config)

    output:
    path "*.quant", emit: diann_quant
    path "*_final_diann.log", emit: log
    path "versions.yml", emit: version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    min_pr_mz = params.min_pr_mz ? "--min-pr-mz $params.min_pr_mz" : ""
    max_pr_mz = params.max_pr_mz ? "--max-pr-mz $params.max_pr_mz" : ""
    min_fr_mz = params.min_fr_mz ? "--min-fr-mz $params.min_fr_mz" : ""
    max_fr_mz = params.max_fr_mz ? "--max-fr-mz $params.max_fr_mz" : ""

    mass_acc = params.mass_acc_ms2
    scan_window = params.scan_window
    ms1_accuracy = params.mass_acc_ms1
    time_corr_only = params.time_corr_only ? "--time-corr-only" : ""

    if (params.mass_acc_automatic | params.scan_window_automatic){
        mass_acc = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 11 | tr -cd \"[0-9]\")"
        scan_window = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 19 | tr -cd \"[0-9]\")"
        ms1_accuracy = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 15 | tr -cd \"[0-9]\")"
    }

    """
    diann   "echo \$(cat ${diann_config})" \\
            --lib ${library} \\
            --f ${mzML} \\
            ${min_pr_mz} \\
            ${max_pr_mz} \\
            ${min_fr_mz} \\
            ${max_fr_mz} \\
            --threads ${task.cpus} \\
            --missed-cleavages $params.allowed_missed_cleavages \\
            --min-pep-len $params.min_peptide_length \\
            --max-pep-len $params.max_peptide_length \\
            --min-pr-charge $params.min_precursor_charge \\
            --max-pr-charge $params.max_precursor_charge \\
            --var-mods $params.max_mods \\
            --verbose $params.diann_debug \\
            --temp ./ \\
            --min-corr $params.min_corr \\
            --corr-diff $params.corr_diff \\
            --mass-acc \$(echo ${mass_acc}) \\
            --mass-acc-ms1 \$(echo ${ms1_accuracy}) \\
            --window \$(echo ${scan_window}) \\
            --no-ifs-removal \\
            ${time_corr_only} \\
            $args \\
            |& tee ${mzML.baseName}_final_diann.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
