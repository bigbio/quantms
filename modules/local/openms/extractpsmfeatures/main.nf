process EXTRACTPSMFEATURES {
    tag "$meta.mzml_id"
    label 'process_very_low'
    label 'process_single'
    label 'openms'

    conda "bioconda::openms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.9.1--h135471a_0' :
        'biocontainers/openms:2.9.1--h135471a_0' }"

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_feat.idXML"), emit: id_files_feat
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    PSMFeatureExtractor \\
        -in ${id_file} \\
        -out ${id_file.baseName}_feat.idXML \\
        -threads $task.cpus \\
        $args \\
        2>&1 | tee ${id_file.baseName}_extract_psm_feature.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PSMFeatureExtractor: \$(PSMFeatureExtractor 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
