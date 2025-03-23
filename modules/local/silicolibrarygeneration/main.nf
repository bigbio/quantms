process SILICOLIBRARYGENERATION {
    tag "$fasta.Name"
    label 'process_medium'
    label 'diann'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'docker.io/biocontainers/diann:v1.8.1_cv1' }"

    input:
    file(fasta)
    file(diann_config)

    output:
    path "versions.yml", emit: versions
    path "*.predicted.speclib", emit: predict_speclib
    path "silicolibrarygeneration.log", emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    min_pr_mz = params.min_pr_mz ? "--min-pr-mz $params.min_pr_mz":""
    max_pr_mz = params.max_pr_mz ? "--max-pr-mz $params.max_pr_mz":""
    min_fr_mz = params.min_fr_mz ? "--min-fr-mz $params.min_fr_mz":""
    max_fr_mz = params.max_fr_mz ? "--max-fr-mz $params.max_fr_mz":""

    """
    diann   `cat diann_config.cfg` \\
            --fasta ${fasta} \\
            --fasta-search \\
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
            --gen-spec-lib \\
            ${args}

    cp lib.log.txt silicolibrarygeneration.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "\\d+\\.\\d+(\\.\\w+)*(\\.[\\d]+)?")
    END_VERSIONS
    """
}
