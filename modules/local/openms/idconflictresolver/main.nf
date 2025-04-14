process IDCONFLICTRESOLVER {
    label 'process_low'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
    path consus_file

    output:
    path "${consus_file.baseName}_resconf.consensusXML", emit: pro_resconf
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    """
    IDConflictResolver \\
        -in ${consus_file} \\
        -threads $task.cpus \\
        -out ${consus_file.baseName}_resconf.consensusXML \\
        $args \\
        2>&1 | tee ${consus_file.baseName}_resconf.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDConflictResolver: \$(IDConflictResolver 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
