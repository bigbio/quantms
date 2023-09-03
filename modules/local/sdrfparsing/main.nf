process SDRFPARSING {
    tag "$sdrf.Name"
    label 'process_low'

    conda "conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.22"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.22--pyhdfd78af_0' :
        'quay.io/biocontainers/sdrf-pipelines:0.0.22--pyhdfd78af_0' }"

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

    ## JSPP 2023-Aug -- Adding --raw for now, this will allow the development of the
    # bypass diann pipelie but break every other aspect of it. Make sure
    # this flag is gone when PRing.
    # Context, without --raw, all file name extenssions are changed to mzML.
    # related: https://github.com/bigbio/sdrf-pipelines/issues/145

    parse_sdrf convert-openms ${args} --raw -t2 -l -s ${sdrf} 2>&1 | tee ${sdrf.baseName}_parsing.log
    mv openms.tsv ${sdrf.baseName}_config.tsv
    mv experimental_design.tsv ${sdrf.baseName}_openms_design.tsv

    # Adding here the removal of the .tar, since DIANN takes the .d directly
    # all logs from the tool match only the .d suffix. so it is easier to
    # remove it here than doing the forensic tracking back of the file.
    sed -i -e "s/((.tar)|(.tar.gz))\\t/\\t/g" ${sdrf.baseName}_openms_design.tsv

    # TODO: since I added support for .gz ... how are we aliasing?
    # if someone packs a .d in a .gz (not .d.gz or .d.tar.gz), how should we
    # know what extension to keep?

    # I am almost sure these do need to be as they exist in the file system
    # before execution.
    # sed -i -e "s/((.tar)|(.tar.gz))\\t/\\t/g" ${sdrf.baseName}_config.tsv

    ## TODO Update the sdrf-pipelines to dynamic print versions
    # Version reporting can now be programmatic, since:
    # https://github.com/bigbio/sdrf-pipelines/pull/134
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(echo "0.0.22")
    END_VERSIONS
    """
}
