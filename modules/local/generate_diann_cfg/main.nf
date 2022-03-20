process GENERATE_DIANN_CFG {
    label 'process_low'


    //TODO What images include click or use sys.args rather than click
    conda (params.enable_conda ? "conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.21" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.21--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/sdrf-pipelines:0.0.21--pyhdfd78af_0"
    }

    input:
    val(meta)
    path(mzmls)

    output:
    path "diann_config.cfg", emit: search_cfg
    path "library_config.cfg", emit: library_config
    path "versions.yml", emit: version


    script:
    def args = task.ext.args ?: ''

    """
    prepare_diann_parameters.py generate \\
        --enzyme "${meta.enzyme}" \\
        --fix_mod "${meta.fixedmodifications}" \\
        --var_mod "${meta.variablemodifications}" \\
        --precursor_tolerence ${meta.precursormasstolerance} \\
        --precursor_tolerence_unit ${meta.precursormasstoleranceunit} \\
        --fragment_tolerence ${meta.fragmentmasstolerance} \\
        --fragment_tolerence_unit ${meta.fragmentmasstoleranceunit} \\
        > GENERATE_DIANN_CFG.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "3.8.3"
    END_VERSIONS
    """
}
