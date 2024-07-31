process MZMLSTATISTICS {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'process_single'

    conda "bioconda::quantms-utils=0.0.2"
    if (workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/quantms-utils:0.0.2--pyhdfd78af_0"
    } else {
        container "biocontainers/quantms-utils:0.0.2--pyhdfd78af_0"
    }

    input:
    tuple val(meta), path(ms_file)

    output:
    path "*_ms_info.parquet", emit: ms_statistics
    tuple val(meta), path("*_spectrum_df.parquet"), emit: spectrum_df, optional: true
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    mzml_statistics.py "${ms_file}" \\
        $params.id_only \\
        2>&1 | tee mzml_statistics.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(pip show pyopenms | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
