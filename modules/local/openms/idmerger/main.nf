process IDMERGER {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    conda "bioconda::openms-thirdparty=3.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:3.1.0--h9ee0642_1' :
        'biocontainers/openms-thirdparty:3.1.0--h9ee0642_1' }"

    input:
    tuple val(meta), path(id_files)

    output:
    tuple val(meta), path("*_merged.idXML"), emit: id_merged
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    if (params.rescore_range == "by_project") {
        if (id_files[0].baseName.contains('sage')){
            prefix = "${meta.experiment_id}_sage"
        } else if (id_files[0].baseName.contains('comet')){
            prefix = "${meta.experiment_id}_comet"
        } else {
            prefix = "${meta.experiment_id}_msgf"
        }
    } else if (params.rescore_range == "by_sample") {
        if (id_files[0].baseName.contains('sage')){
            prefix = "${meta.mzml_id}_sage"
        } else if (id_files[0].baseName.contains('comet')){
            prefix = "${meta.mzml_id}_comet"
        } else {
            prefix = "${meta.mzml_id}_msgf"
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
