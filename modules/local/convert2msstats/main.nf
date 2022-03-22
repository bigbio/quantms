process CONVERT2MSSTATS {
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.21" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.21--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/sdrf-pipelines:0.0.21--pyhdfd78af_0"
    }

    input:
    path(report)
    path(exp_design)

    output:
    path "*.csv", emit: out_msstats
    path "versions.yml", emit: version

    script:
    def args = task.ext.args ?: ''

    """
    convert_msstats.py convert_msstats \\
        --diann_report ${report} \\
        --exp_design ${exp_design} \\
        > trans_to_msstats.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(echo "0.0.21")
    END_VERSIONS
    """
}
