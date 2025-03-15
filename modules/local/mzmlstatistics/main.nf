process MZMLSTATISTICS {
    tag "$meta.mzml_id"
    label 'process_very_low'
    label 'process_single'

    conda "bioconda::quantms-utils=0.0.20"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quantms-utils:0.0.20--pyh7e72e81_0' :
        'biocontainers/quantms-utils:0.0.20--pyh7e72e81_0' }"

    input:
    tuple val(meta), path(ms_file)

    output:
    path "*_ms_info.parquet", emit: ms_statistics
    tuple val(meta), path("*_spectrum_df.parquet"), emit: spectrum_df, optional: true
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"
    def string_ms2_file = params.id_only == true || params.mzml_features == true ? "--ms2_file" : ""
    def string_features_file = params.mzml_features == true ? "--feature_detection" : ""

    """
    quantmsutilsc mzmlstats --ms_path "${ms_file}" \\
        ${string_ms2_file} \\
        ${string_features_file} \\
        2>&1 | tee mzml_statistics.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-utils: \$(pip show quantms-utils | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
