process GENERATE_DIANN_CFG {
    tag "$meta.experiment_id"
    label 'process_low'

    conda 'conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.22'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.22--pyhdfd78af_0' :
        'biocontainers/sdrf-pipelines:0.0.22--pyhdfd78af_0' }"


    input:
    val(meta)

    output:
    path 'diann_config.cfg', emit: diann_cfg
    path 'versions.yml', emit: version
    path '*.log'

    script:
    def args = task.ext.args ?: ''

    """
    prepare_diann_parameters.py generate \\
        --enzyme "${meta.enzyme}" \\
        --fix_mod "${meta.fixedmodifications}" \\
        --var_mod "${meta.variablemodifications}" \\
        2>&1 | tee GENERATE_DIANN_CFG.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(pip show sdrf-pipelines | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
