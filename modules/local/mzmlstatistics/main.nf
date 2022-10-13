process MZMLSTATISTICS {
    label 'process_medium'
    // TODO could be easily parallelized
    label 'process_single_thread'

    conda (params.enable_conda ? "bioconda::pyopenms=2.8.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pyopenms:2.8.0--py38hd8d5640_1"
    } else {
        container "quay.io/biocontainers/pyopenms:2.8.0--py38hd8d5640_1"
    }

    input:
    path("out/*")

    output:
    path "mzml_info.tsv", emit: mzml_statistics
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    """
    mzml_statistics.py "./out/" \\
        |& tee mzml_statistics.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print (pyopenms.__version__)")
    END_VERSIONS
    """
}
