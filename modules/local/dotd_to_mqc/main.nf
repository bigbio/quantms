/* groovylint-disable DuplicateStringLiteral */
process DOTD2MQC_INDIVIDUAL {
    tag "$meta.experiment_id"
    label 'process_single'

    conda "base::python=3.10"
    conda "conda-forge::python=3.10"
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/python:3.10"
    } else {
        container "quay.io/biocontainers/python:3.10"
    }

    input:
    // Note: This step can be optimized by staging only the
    // .tdf file inside the .d directory.
    // Thus reducing the data transfer of the rest of the .d
    // directory. IN PARTICULAR the .tdf.bin
    tuple val(meta), path(dot_d_file)

    output:
    tuple path("dotd_mqc.yml"), path("*.tsv"), emit: dotd_mqc_data
    path "general_stats*.tsv", emit: general_stats
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    dotd_2_mqc.py single "${dot_d_file}" \${PWD}  \\
        2>&1 | tee dotd_2_mqc_${prefix}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dotd_2_mqc: \$(dotd_2_mqc.py --version | grep -oE "\\d\\.\\d\\.\\d")
        dotd_2_mqc_python: \$(python --version | grep -oE "\\d\\.\\d\\.\\d")
    END_VERSIONS
    """
}


process DOTD2MQC_AGGREGATE {
    label 'process_single'

    conda "conda-forge::python=3.10"
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/python:3.10"
    } else {
        container "quay.io/biocontainers/python:3.10"
    }

    input:
    path '*' // tsv files from DOTD2MQC_INDIVIDUAL

    output:
    path 'general_stats.tsv', emit: dotd_mqc_data
    path 'versions.yml', emit: version
    path '*.log', emit: log

    script:
    """
    ls -lcth

    dotd_2_mqc.py aggregate \${PWD} \${PWD}  \\
        2>&1 | tee dotd_2_mqc_agg.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dotd_2_mqc: \$(dotd_2_mqc.py --version | grep -oE "\\d\\.\\d\\.\\d")
        dotd_2_mqc_python: \$(python --version | grep -oE "\\d\\.\\d\\.\\d")
    END_VERSIONS
    """
}
