process FALSE_DISCOVERY_RATE {
    tag "$meta.mzml_id"
    label 'process_low'
    label 'process_single'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_fdr.idXML"), emit: id_files_idx_ForIDPEP_FDR
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    FalseDiscoveryRate \\
        -in ${id_file} \\
        -out ${id_file.baseName}_fdr.idXML \\
        -threads $task.cpus \\
        -algorithm:add_decoy_peptides \\
        -algorithm:add_decoy_proteins \\
        $args \\
        2>&1 | tee ${id_file.baseName}_fdr.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        FalseDiscoveryRate: \$(FalseDiscoveryRate 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
