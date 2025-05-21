process DIANN_GENERATE_CFG {
    tag "$meta.experiment_id"
    label 'process_tiny'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quantms-utils:0.0.23--pyh7e72e81_0' :
        'biocontainers/quantms-utils:0.0.23--pyh7e72e81_0' }"

    input:
    val(meta)

    output:
    path 'diann_config.cfg', emit: diann_cfg
    path 'versions.yml', emit: versions
    path '*.log'

    script:
    def args = task.ext.args ?: ''

    """
    quantmsutilsc dianncfg \\
        --enzyme "${meta.enzyme}" \\
        --fix_mod "${meta.fixedmodifications}" \\
        --var_mod "${meta.variablemodifications}" \\
        2>&1 | tee GENERATE_DIANN_CFG.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-utils: \$(pip show quantms-utils | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
