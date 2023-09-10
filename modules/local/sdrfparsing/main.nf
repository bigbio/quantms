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
    path "${sdrf.baseName}_openms_design.tsv", emit: ch_expdesign
    path "${sdrf.baseName}_config.tsv"       , emit: ch_sdrf_config_file
    path "*.log"                             , emit: log
    path "versions.yml"                      , emit: version

    script:
    def args = task.ext.args ?: ''
    // TODO Read the `convert_dotd` parameter and dispatch parameters accprdingly

    """
    ## -t2 since the one-table format parser is broken in OpenMS2.5
    ## -l for legacy behavior to always add sample columns
    
    parse_sdrf convert-openms -t2 -l --extension_convert raw:mzML -s ${sdrf} 2>&1 | tee ${sdrf.baseName}_parsing.log

    mv openms.tsv ${sdrf.baseName}_config.tsv
    mv experimental_design.tsv ${sdrf.baseName}_openms_design.tsv

    # Adding here the removal of the .tar, since DIANN takes the .d directly
    # all logs from the tool match only the .d suffix. so it is easier to
    # remove it here than doing the forensic tracking back of the file.
    sed -i -e "s/((.tar)|(.tar.gz))\\t/\\t/g" ${sdrf.baseName}_openms_design.tsv

    # TODO: since I added support for .gz ... how are we aliasing?
    # if someone packs a .d in a .gz (not .d.gz or .d.tar.gz), how should we
    # know what extension to keep?

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(parse_sdrf --version 2>&1 | awk -F ' ' '{print \$2}')
    END_VERSIONS
    """
}
