process SAGEFEATURE {
    tag "$meta.mzml_id"
    label 'process_low'

    conda "bioconda::quantms-utils=0.0.16"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quantms-utils:0.0.16--pyhdfd78af_0' :
        'biocontainers/quantms-utils:0.0.16--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(id_file), path(extra_feat)

    output:
    tuple val(meta), path("${id_file.baseName}_feat.idXML"), emit: id_files_feat
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    quantmsutilsc sage2feature --idx_file "${id_file}" --output_file "${id_file.baseName}_feat.idXML" --feat_file "${extra_feat}" 2>&1 | tee add_sage_feature.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-utils: \$(pip show quantms-utils | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
