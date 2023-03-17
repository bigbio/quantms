process MZMLSTATISTICS {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'process_single_thread'

    conda "bioconda::pyopenms=2.8.0"
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pyopenms:2.8.0--py38hd8d5640_1"
    } else {
        container "quay.io/biocontainers/pyopenms:2.8.0--py38hd8d5640_1"
    }

    input:
    tuple val(meta), path(mzml_file.mzml)

    output:
    path "*_mzml_info.tsv", emit: mzml_statistics
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    mzml_statistics.py "${mzml_file}" \\
        2>&1 | tee mzml_statistics.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(pip show pyopenms | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
