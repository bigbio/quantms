process GETSAMPLE {
    tag "$design.Name"
    label 'process_low'

    conda "bioconda::sdrf-pipelines=0.0.25"
    if (workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.25--pyhdfd78af_0"
    } else {
        container "biocontainers/sdrf-pipelines:0.0.25--pyhdfd78af_0"
    }

    input:
    path design

    output:
    path "*_sample.csv", emit: ch_expdesign_sample
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    extract_sample.py "${design}" 2>&1 | tee extract_sample.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(parse_sdrf --version 2>&1 | awk -F ' ' '{print \$2}')
    END_VERSIONS
    """
}
