process GETSAMPLE {
    tag "$design.Name"
    label 'process_low'

    conda "bioconda::quantms-utils=0.0.17"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quantms-utils:0.0.17--pyh7e72e81_0' :
        'biocontainers/quantms-utils:0.0.17--pyh7e72e81_0' }"


    input:
    path design

    output:
    path "*_sample.csv", emit: ch_expdesign_sample
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    quantmsutilsc openms2sample --expdesign "${design}" 2>&1 | tee extract_sample.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(parse_sdrf --version 2>&1 | awk -F ' ' '{print \$2}')
    END_VERSIONS
    """
}
