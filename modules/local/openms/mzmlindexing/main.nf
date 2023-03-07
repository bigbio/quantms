process MZMLINDEXING {
    tag "$meta.mzml_id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::openms=2.9.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.9.0--h135471a_0' :
        'quay.io/biocontainers/openms:2.9.0--h135471a_0' }"

    input:
    tuple val(meta), path(mzmlfile)

    output:
    tuple val(meta), path("out/*.mzML"), emit: mzmls_indexed
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    mkdir -p out
    FileConverter -in ${mzmlfile} -out out/${mzmlfile.baseName}.mzML |& tee ${mzmlfile.baseName}_mzmlindexing.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        FileConverter: \$(FileConverter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
