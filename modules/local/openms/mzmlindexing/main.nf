process MZMLINDEXING {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.8.0--h7ca0330_1' :
        'quay.io/biocontainers/openms:2.8.0--h7ca0330_1' }"

    input:
    tuple val(meta), path(mzmlfile)

    output:
    tuple val(meta), path("out/*.mzML"), emit: mzmls_indexed
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir out
    FileConverter -in ${mzmlfile} -out out/${mzmlfile.baseName}.mzML > ${mzmlfile.baseName}_mzmlindexing.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        FileConverter: \$(FileConverter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
