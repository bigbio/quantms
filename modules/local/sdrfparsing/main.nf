process SDRFPARSING {
    tag "$sdrf.Name"
    label 'process_low'

    conda "conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.23"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.23--pyhdfd78af_0' :
        'quay.io/biocontainers/sdrf-pipelines:0.0.23--pyhdfd78af_0' }"

    input:
    path sdrf

    output:
    path "${sdrf.baseName}_openms_design.tsv", optional: true, emit: ch_expdesign
    path "${sdrf.baseName}_config.tsv", optional: true, emit: ch_sdrf_config_file
    path "*.xml", optional: true, emit: mqpar
    path "*.log", emit: log
    path "versions.yml", emit: version

    script:
    def args = task.ext.args ?: ''

    """
    ## -t2 since the one-table format parser is broken in OpenMS2.5
    ## -l for legacy behavior to always add sample columns
    ## TODO Update the sdrf-pipelines to dynamic print versions

    parse_sdrf convert-openms -t2 -l --extension_convert raw:mzML -s ${sdrf} 2>&1 | tee ${sdrf.baseName}_parsing.log
    mv openms.tsv ${sdrf.baseName}_config.tsv
    mv experimental_design.tsv ${sdrf.baseName}_openms_design.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(echo "0.0.23")
    END_VERSIONS
    """
}
