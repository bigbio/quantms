process IDSCORESWITCHER {
    tag "$meta.mzml_id"
    label 'process_very_low'
    label 'process_single_thread'

    conda (params.enable_conda ? "bioconda::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://ftp.pride.ebi.ac.uk/pub/databases/pride/resources/tools/ghcr.io-openms-openms-executables-latest.img' :
        'ghcr.io/openms/openms-executables:latest' }"

    input:
    tuple val(meta), path(id_file), val(new_score)

    output:
    tuple val(meta), path("${id_file.baseName}_pep.idXML"), emit: id_score_switcher
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    IDScoreSwitcher \\
        -in ${id_file} \\
        -out ${id_file.baseName}_pep.idXML \\
        -threads $task.cpus \\
        -new_score ${new_score} \\
        $args \\
        |& tee ${id_file.baseName}_switch.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDScoreSwitcher: \$(IDScoreSwitcher 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
