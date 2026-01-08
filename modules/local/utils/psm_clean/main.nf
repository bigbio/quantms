process PSM_CLEAN {
    tag "$meta.mzml_id"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/quantms-rescoring-sif:0.0.13' :
        'ghcr.io/bigbio/quantms-rescoring:0.0.13' }"

    input:
    tuple val(meta), path(idxml), path(mzml)

    output:
    tuple val(meta), path("*clean.idXML") , emit: idxml
    path "versions.yml"                   , emit: versions
    path "*.log"                          , emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}_clean"

    """
    rescoring psm_feature_clean \\
        --idxml $idxml \\
        --mzml $mzml \\
        --output ${idxml.baseName}_clean.idXML \\
        $args \\
        2>&1 | tee ${idxml.baseName}_clean.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-rescoring: \$(rescoring --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
    END_VERSIONS
    """
}
