process PSM_CLEAN {
    tag "$meta.mzml_id"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/quantms-rescoring-sif:0.0.18' :
        'ghcr.io/bigbio/quantms-rescoring:0.0.18' }"

    input:
    tuple val(meta), path(idparquet), path(mzml)

    output:
    tuple val(meta), path("*clean.idparquet") , emit: idparquet
    path "versions.yml"                   , emit: versions
    path "*.log"                          , emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}_clean"

    """
    rescoring psm_feature_clean \\
        --idparquet ${idparquet.join(' --idparquet ')} \\
        --mzml $mzml \\
        --output ${mzml.baseName}_clean.idparquet \\
        $args \\
        2>&1 | tee ${mzml.baseName}_clean.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-rescoring: \$(rescoring --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
    END_VERSIONS
    """
}
