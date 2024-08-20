process SPECTRUM2FEATURES {
    tag "$meta.mzml_id"
    label 'process_low'

    conda "bioconda::quantms-utils=0.0.9"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quantms-utils:0.0.9--pyhdfd78af_0' :
        'biocontainers/quantms-utils:0.0.9--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(id_file), path(ms_file)

    output:
    tuple val(meta), path("${id_file.baseName}_snr.idXML"), emit: id_files_snr
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    quantmsutilsc spectrum2feature --ms_path "${ms_file}" --idxml "${id_file}" --output "${id_file.baseName}_snr.idXML" 2>&1 | tee add_snr_feature.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-utils: \$(pip show quantms-utils | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
