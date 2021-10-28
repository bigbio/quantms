// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process THERMORAWFILEPARSER {
    label 'process_low'
    label 'process_single_thread'
    publishDir "${params.outdir/logs}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.7.0pre--0"
    } else {
        container "quay.io/biocontainers/openms-thirdparty:2.7.0pre--0"
    }

    input:
    tuple val(mzml_id), path(rawfile)

    output:
    tuple val(mzml_id), path("*.mzML"), emit: mzmls_converted
    path  "*.version.txt"          , emit: version

    script:
    // Add soft-links to original FastQs for consistent naming in pipeline
    def software = getSoftwareName(task.process)
    """
    ThermoRawFileParser.sh -i=${rawfile} -f=2 -o=./ > ${rawfile}_conversion.log
    """
}
