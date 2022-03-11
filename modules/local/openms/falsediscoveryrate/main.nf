process FALSEDISCOVERYRATE {
    label 'process_very_low'
    label 'process_single_thread'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_fdr.idXML"), emit: id_files_idx_ForIDPEP_FDR
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    FalseDiscoveryRate \\
        -in ${id_file} \\
        -out ${id_file.baseName}_fdr.idXML \\
        -threads $task.cpus \\
        -protein false \\
        -algorithm:add_decoy_peptides \\
        -algorithm:add_decoy_proteins \\
        $args \\
        > ${id_file.baseName}_fdr.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        FalseDiscoveryRate: \$(FalseDiscoveryRate 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
