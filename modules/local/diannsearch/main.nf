process DIANNSEARCH {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'biocontainers/diann:v1.8.1_cv1' }"

    input:
    file 'mzMLs/*'
    file(lib_tsv)
    file(searchdb)
    file(diann_config)

    output:
    path "diann_report.tsv", emit: report
    path "diann_report.stats.tsv", emit: report_stat
    path "diann_report.log.txt", emit: log
    path "versions.yml", emit: version
    path "*.tsv"

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    mbr = params.targeted_only ? "" : "--reanalyse"
    normalize = params.diann_normalize ? "" : "--no-norm"

    min_pr_mz = params.min_pr_mz ? "--min-pr-mz params.min_pr_mz":""
    max_pr_mz = params.max_pr_mz ? "--max-pr-mz params.max_pr_mz":""
    min_fr_mz = params.min_fr_mz ? "--min_fr_mz params.min_fr_mz":""
    max_fr_mz = params.max_fr_mz ? "--max_fr_mz params.max_fr_mz":""

    """
    diann   `cat diann_config.cfg` \\
            --lib ${(lib_tsv as List).join('--lib ')} \\
            --relaxed-prot-inf \\
            --fasta ${searchdb} \\
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
            --matrix-spec-q $params.matrix_spec_q \\
            ${mbr} \\
            --reannotate \\
            ${normalize} \\
            --out diann_report.tsv \\
            --verbose $params.diann_debug \\
            |& tee diann.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
