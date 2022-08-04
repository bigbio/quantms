process LIBRARYGENERATION {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'biocontainers/diann:v1.8.1_cv1' }"

    input:
    tuple file(mzml), file(fasta)
    file(library_config)

    output:
    path "*_lib.tsv", emit: lib_splib
    path "versions.yml", emit: version
    path "report.log.txt", emit: log
    path "*.tsv.speclib", emit: speclib
    path "*.predicted.speclib", emit: predict_speclib

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    min_pr_mz = params.min_pr_mz ? "--min-pr-mz $params.min_pr_mz":""
    max_pr_mz = params.max_pr_mz ? "--max-pr-mz $params.max_pr_mz":""
    min_fr_mz = params.min_fr_mz ? "--min_fr_mz $params.min_fr_mz":""
    max_fr_mz = params.max_fr_mz ? "--max_fr_mz $params.max_fr_mz":""

    """
    diann   `cat library_config.cfg` \\
            --fasta ${fasta} \\
            --fasta-search \\
            --f ${mzml} \\
            --out-lib ${mzml.baseName}_lib.tsv \\
            ${min_pr_mz} \\
            ${max_pr_mz} \\
            ${min_fr_mz} \\
            ${max_fr_mz} \\
            --missed-cleavages $params.allowed_missed_cleavages \\
            --min-pep-len $params.min_peptide_length \\
            --max-pep-len $params.max_peptide_length \\
            --min-pr-charge $params.min_precursor_charge \\
            --max-pr-charge $params.max_precursor_charge \\
            --var-mods $params.max_mods \\
            --threads ${task.cpus} \\
            --predictor \\
            --verbose $params.diann_debug \\
            |& tee diann.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
