process DECOYDATABASE {
    label 'process_very_low'
    label 'openms'

    conda (params.enable_conda ? "bioconda::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.8.0--h7ca0330_1' :
        'quay.io/biocontainers/openms:2.8.0--h7ca0330_1' }"

    input:
    path(db_for_decoy)

    output:
    path "*.fasta",   emit: db_decoy
    path "versions.yml", emit: version
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
        |& tee ${db_for_decoy.baseName}_decoy_database.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DecoyDatabase: \$(DecoyDatabase 2>&1  | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
