// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process THERMORAWFILEPARSER {
    tag "$meta.id"
    label 'process_low'
    label 'process_single_thread'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "conda-forge::mono bioconda::thermorawfileparser=1.3.4" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/thermorawfileparser:1.3.4--ha8f3691_0"
    } else {
        container "quay.io/biocontainers/thermorawfileparser:1.3.4--ha8f3691_0"
    }

    input:
    tuple val(meta), path(rawfile)

    output:
    tuple val(meta), path("*.mzML"), emit: mzmls_converted
    path "*.version.txt",   emit: version
    path "*.log",   emit: log

    script:
    def software = getSoftwareName(task.process)
    """
    ThermoRawFileParser.sh -i=${rawfile} -f=2 -o=./ > ${rawfile.baseName}_conversion.log

    ThermoRawFileParser.sh --version > ${software}.version.txt
    """
}
