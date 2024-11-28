process EXTRACTPSMFEATURES {
    tag "$meta.mzml_id"
    label 'process_very_low'
    label 'process_single'
    label 'openms'

    conda "bioconda::openms-thirdparty=3.2.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:3.2.0--h9ee0642_4' :
        'biocontainers/openms-thirdparty:3.2.0--h9ee0642_4' }"

    input:
    tuple val(meta), path(id_file), path(extra_feat)

    output:
    tuple val(meta), path("${id_file.baseName}_feat.idXML"), emit: id_files_feat
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    feature = ""
    if (params.ms2rescore && params.id_only) {
        feature = "-extra \$(awk 'NR > 1 && \$1 !~ /psm_file/ {printf \"%s \", \$2}' ${extra_feat})"
    }

    """
    PSMFeatureExtractor \\
        -in ${id_file} \\
        -out ${id_file.baseName}_feat.idXML \\
        -threads $task.cpus \\
        ${feature} \\
        $args \\
        2>&1 | tee ${id_file.baseName}_extract_psm_feature.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PSMFeatureExtractor: \$(PSMFeatureExtractor 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
