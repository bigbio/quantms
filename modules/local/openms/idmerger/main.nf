process IDMERGER {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    conda "bioconda::openms-thirdparty=3.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:3.3.0--h9ee0642_4' :
        'biocontainers/openms-thirdparty:3.3.0--h9ee0642_4' }"

    input:
    tuple val(meta), path(id_files), val(groupkey)

    output:
    tuple val(meta), path("*_merged.idXML"), emit: id_merged
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${groupkey}"

    if (params.rescore_range == "by_project") {
        if (id_files[0].baseName.contains('sage')){
            prefix = "${groupkey}_sage"
        } else if (id_files[0].baseName.contains('comet')){
            prefix = "${groupkey}_comet"
        } else {
            prefix = "${groupkey}_msgf"
        }
    } else if (params.rescore_range == "by_sample") {
        if (id_files[0].baseName.contains('sage')){
            prefix = "${groupkey}_sage"
        } else if (id_files[0].baseName.contains('comet')){
            prefix = "${groupkey}_comet"
        } else {
            prefix = "${groupkey}_msgf"
        }
    }

    """
    IDMerger \\
        -in ${id_files.join(' ')} \\
        -threads $task.cpus \\
        -out ${prefix}_merged.idXML \\
        -merge_proteins_add_PSMs \\
        $args \\
        2>&1 | tee ${prefix}_merged.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDMerger: \$(IDMerger 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
