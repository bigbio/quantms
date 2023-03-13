process MZMLSTATISTICS {
    label 'process_medium'
    // TODO could be easily parallelized
    label 'process_single_thread'

    conda "bioconda::pyopenms=2.9.1"
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pyopenms:2.9.1--py38hd8d5640_1"
    } else {
        container "quay.io/biocontainers/pyopenms:2.9.1--py38hd8d5640_1"
    }

    input:
    path mzml_path

    output:
    path "*_mzml_info.tsv", emit: mzml_statistics
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    """
    mzml_statistics.py "${mzml_path}" \\
        2>&1 | tee mzml_statistics.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(pip show pyopenms | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
