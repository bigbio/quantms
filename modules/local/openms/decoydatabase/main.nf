process DECOYDATABASE {
    label 'process_very_low'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.12' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.12' }"

    input:
    path(db_for_decoy)

    output:
    path "*.fasta",   emit: db_decoy
    path "versions.yml", emit: versions
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''

    """
    DecoyDatabase \\
        -in ${db_for_decoy} \\
        -out ${db_for_decoy.baseName}_decoy.fasta \\
        -decoy_string $params.decoy_string \\
        -decoy_string_position $params.decoy_string_position \\
        -method $params.decoy_method \\
        -shuffle_max_attempts $params.shuffle_max_attempts \\
        -shuffle_sequence_identity_threshold $params.shuffle_sequence_identity_threshold \\
        -debug $params.decoydatabase_debug \\
        $args \\
        2>&1 | tee ${db_for_decoy.baseName}_decoy_database.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DecoyDatabase: \$(DecoyDatabase 2>&1  | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
