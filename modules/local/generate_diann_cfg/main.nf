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
    path("*.mzML"), includeInputs: true, emit: mzmls_for_diann
    path "*.cfg", emit: diann_cfg
    path "versions.yml", emit: version


    script:
    def args = task.ext.args ?: ''

    """
    prepare_diann_parameters.py generate \\
        --unimod_csv ${projectDir}/assets/unimod.csv \\
        --enzyme "${meta[0].enzyme}" \\
        --fix_mod "${meta[0].fixedmodifications}" \\
        --var_mod "${meta[0].variablemodifications}" \\
        --precursor_tolerence ${meta[0].precursormasstolerance} \\
        --precursor_tolerence_unit ${meta[0].precursormasstoleranceunit} \\
        --fragment_tolerence ${meta[0].fragmentmasstolerance} \\
        --fragment_tolerence_unit ${meta[0].fragmentmasstoleranceunit} \\
        > GENERATE_DIANN_CFG.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "3.8.3"
    END_VERSIONS
    """
}
