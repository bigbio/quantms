// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process DECOYDATABASE {
    label 'process_very_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://ftp.pride.ebi.ac.uk/pride/data/tools/quantms-dev.sif"
    } else {
        container "quay.io/bigbio/quantms:dev"
    }

    input:
    path(db_for_decoy)

    output:
    path "*.fasta",   emit: db_decoy
    path "*.version.txt", emit: version
    path "*.log",   emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    DecoyDatabase \\
        -in ${db_for_decoy} \\
        -out ${db_for_decoy.baseName}_decoy.fasta \\
        -decoy_string $params.decoy_string \\
        -decoy_string_position $params.decoy_string_position \\
        -method $params.decoy_method \\
        -shuffle_max_attempts $params.shuffle_max_attempts \\
        -shuffle_sequence_identity_threshold $params.shuffle_sequence_identity_threshold \\
        -debug 100 \\
        $options.args \\
        > ${db_for_decoy.baseName}_decoy_database.log

    echo \$(DecoyDatabase --version 2>&1) > ${software}.version.txt
    """
}
