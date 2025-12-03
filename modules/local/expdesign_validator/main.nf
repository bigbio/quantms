process EXPDESIGN_VALIDATOR {
    tag "$expdesign.name"
    label 'process_tiny'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9' :
        'biocontainers/python:3.9' }"

    input:
    path expdesign

    output:
    path "${expdesign}", emit: ch_validated_expdesign
    path "*.log"       , emit: log
    path "versions.yml", emit: versions

    script:
    """
    validate_expdesign.py --expdesign "${expdesign}" 2>&1 | tee validation.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
