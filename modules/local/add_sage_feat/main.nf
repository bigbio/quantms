process SAGEFEATURE {
    tag "$meta.mzml_id"
    label 'process_low'

    conda "bioconda::quantms-utils=0.0.2"
    if (workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/quantms-utils:0.0.2--pyhdfd78af_0"
    } else {
        container "biocontainers/quantms-utils:0.0.2--pyhdfd78af_0"
    }

    input:
    tuple val(meta), path(id_file), path(extra_feat)

    output:
    tuple val(meta), path("${id_file.baseName}_feat.idXML"), emit: id_files_feat
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    quantmsutilsc sage2feature --idx_file "${id_file}" --output_file "${id_file.baseName}_feat.idXML" --feat_file "${extra_feat}" 2>&1 | tee add_sage_feature.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(pip show pyopenms | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
