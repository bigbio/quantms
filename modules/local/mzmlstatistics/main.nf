process MZMLSTATISTICS {
    label 'process_medium'
    // TODO could be easily parallelized
    label 'process_single_thread'

    conda (params.enable_conda ? "bioconda::pyopenms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.8.0--h7ca0330_1' :
        'quay.io/biocontainers/openms:2.8.0--h7ca0330_1' }"

    input:
    path("out/*")

    output:
    path "mzml_info.tsv", emit: mzml_statistics
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    """
    python /home/qinchunyuan/proteomicsDIA/quantms-statistics/bin/mzml_statistics.py mzml_dataframe \\
        --mzml_folder "./out/" \\
        |& tee mzml_statistics.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(echo "2.8.0")
    END_VERSIONS
    """
}