process DIANN_MSSTATS {
    tag "$meta.experiment_id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quantms-utils:0.0.25--pyh106432d_0' :
        'biocontainers/quantms-utils:0.0.25--pyh106432d_0' }"

    input:
    path(report)
    path(exp_design)
    path(report_pg)
    path(report_pr)
    val(meta)
    path(fasta)

    output:
    path "*msstats_in.csv", emit: out_msstats
    path "*.log", emit: log
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    quantmsutilsc diann2msstats \\
        --report ${report} \\
        --exp_design ${exp_design} \\
        --qvalue_threshold $params.protein_level_fdr_cutoff \\
        $args \\
        2>&1 | tee convert_report.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-utils: \$(pip show quantms-utils | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
