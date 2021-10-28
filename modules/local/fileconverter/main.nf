// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process FILECONVERTER {
    label 'process_low'
    publishDir "${params.outdir}/logs",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        // TODO Need to built single container
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.7.0pre--0"
    } else {
        // TODO Need to built single container
        container "quay.io/biocontainers/openms-thirdparty:2.7.0pre--0"
    }

    input:
    tuple val(mzml_id), path(mzmlfile)

    output:
    tuple val(mzml_id), path("*.mzML"), emit: mzmls_indexed
    path "*.version.txt"          , emit: version

    script:
    def software = getSoftwareName(task.process)
    """
    mkdir out
    FileConverter -in ${mzmlfile} -out out/${mzmlfile.baseName}.mzML > ${mzmlfile.baseName}_mzmlindexing.log

    echo \$(FileConverter 2>&1) > ${software}.version.txt
    """
}
