process SDRFPARSING {
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.21" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.21--pyhdfd78af_0' :
        'quay.io/biocontainers/sdrf-pipelines:0.0.21--pyhdfd78af_0' }"

    input:
    path sdrf

    output:
    path "experimental_design.tsv", optional:true, emit: ch_expdesign
    path "openms.tsv", optional:true, emit: ch_sdrf_config_file
    path "*.xml", optional:true, emit: mqpar
    path "*.log", emit: log
    path "versions.yml", emit: version

    script:
    def args = task.ext.args ?: ''

    """
    ## -t2 since the one-table format parser is broken in OpenMS2.5
    ## -l for legacy behavior to always add sample columns
    ## TODO Update the sdrf-pipelines to dynamic print versions

    parse_sdrf convert-openms -t2 -l -s ${sdrf} |& tee sdrf_parsing.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(echo "0.0.21")
    END_VERSIONS
    """
}
