process SAGEFEATURE {
    tag "$meta.mzml_id"
    label 'process_low'

    conda "bioconda::pyopenms=3.1.0"
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pyopenms:3.1.0--py39h9b8898c_0"
    } else {
        container "biocontainers/pyopenms:3.1.0--py39h9b8898c_0"
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
    add_sage_feature.py "${id_file}" "${id_file.baseName}_feat.idXML" "${extra_feat}" 2>&1 | tee add_sage_feature.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(pip show pyopenms | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
