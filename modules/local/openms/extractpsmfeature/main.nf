process EXTRACTPSMFEATURE {
    label 'process_very_low'
    label 'process_single_thread'

    conda (params.enable_conda ? "bioconda::openms=2.8.0 bioconda::percolator=3.5 bioconda::openms-thirdparty=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_feat.idXML"), emit: id_files_idx_feat
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    PSMFeatureExtractor \\
        -in ${id_file} \\
        -out ${id_file.baseName}_feat.idXML \\
        -threads $task.cpus \\
        $args \\
        > ${id_file.baseName}_extract_psm_feature.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PSMFeatureExtractor: \$(PSMFeatureExtractor 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
