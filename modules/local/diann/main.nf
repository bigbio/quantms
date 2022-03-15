process DIANN {
    label 'process_high'

    if (params.enable_conda) {
        exit 1, "Conda environments cannot be used when using the DIA-NN tool. Please use docker or singularity containers"
    }

    //singularity image ?
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "biocontainers/diann:v1.8.0_cv1"
    } else {
        container "biocontainers/diann:v1.8.0_cv1"
    }

    input:
    file 'mzMLs/*'
    file(fasta)
    file(diann_config)

    output:
    path "report.tsv", emit: report
    path "report.stats.tsv", emit: report_stat
    path "report.log.txt", emit: log
    path "versions.yml", emit: version
    path "*.tsv"

    script:
    def args = task.ext.args ?: ''
    il_eq = params.IL_equivalent ? "--il-eq" : ""
    mbr = params.targeted_only ? "" : "--reanalyse"

    """
    diann   `cat diann_config.cfg` \\
            --fasta ${fasta} \\
            --threads ${task.cpus} \\
            --missed-cleavages $params.allowed_missed_cleavages \\
            --min-pep-len $params.min_peptide_length \\
            --max-pep-len $params.max_peptide_length \\
            --min-pr-charge $params.min_precursor_charge \\
            --max-pr-charge $params.max_precursor_charge \\
            --var-mods $params.max_mods \\
            --matrix-spec-q $params.matrix_spec_q \\
            ${il_eq} \\
            ${mbr} \\
            --verbose $params.diann_debug \\


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        diann: "1.8.0"
    END_VERSIONS
    """
}
