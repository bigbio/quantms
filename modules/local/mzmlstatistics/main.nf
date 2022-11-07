process MZMLSTATISTICS {
    label 'process_medium'
    // TODO could be easily parallelized
    label 'process_single_thread'

    conda (params.enable_conda ? "conda-forge::pandas_schema conda-forge::lzstring bioconda::pmultiqc=0.0.17" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pmultiqc:0.0.17--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/pmultiqc:0.0.17--pyhdfd78af_0"
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
    mzml_statistics.py mzml_dataframe \\
        --mzml_folder "./out/" \\
        |& tee mzml_statistics.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(echo "2.8.0")
    END_VERSIONS
    """
}
