process GENERATE_DIANN_CFG {
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.21" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.21--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/sdrf-pipelines:0.0.21--pyhdfd78af_0"
    }

    input:
    val(meta)

    output:
    path "diann_config.cfg", emit: diann_cfg
    path "versions.yml", emit: version
    path "*.log"

    script:
    def args = task.ext.args ?: ''

    """
    prepare_diann_parameters.py generate \\
        --enzyme "${meta.enzyme}" \\
        --fix_mod "${meta.fixedmodifications}" \\
        --var_mod "${meta.variablemodifications}" \\
        |& tee GENERATE_DIANN_CFG.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(echo "0.0.21")
    END_VERSIONS
    """
}
