process DIANN_PRELIMINARY_ANALYSIS {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'biocontainers/diann:v1.8.1_cv1' }"

    input:
    tuple file(mzML), file(predict_tsv), file(diann_config)

    output:
    path "*.quant", emit: diann_quant
    path "${mzML.baseName}_lib.tsv", emit: lib
    path "*.log.txt", emit: log
    path "versions.yml", emit: version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    min_pr_mz = params.min_pr_mz ? "--min-pr-mz $params.min_pr_mz" : ""
    max_pr_mz = params.max_pr_mz ? "--max-pr-mz $params.max_pr_mz" : ""
    min_fr_mz = params.min_fr_mz ? "--min-fr-mz $params.min_fr_mz" : ""
    max_fr_mz = params.max_fr_mz ? "--max-fr-mz $params.max_fr_mz" : ""

    quick_mass_acc = params.quick_mass_acc ? "--quick-mass-acc" : ""
    time_corr_only = params.time_corr_only ? "--time-corr-only" : ""

    """
    diann   `cat diann_config.cfg` \\
            --lib ${predict_tsv} \\
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
            --window $params.scan_window \\
            --gen-spec-lib \\
            --out-lib ${mzML.baseName}_lib.tsv \\
            --temp ./ \\
            --min-corr $params.min_corr \\
            --corr-diff $params.corr_diff \\
            ${quick_mass_acc} \\
            ${time_corr_only} \\
            $args \\
            |& tee diann.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
