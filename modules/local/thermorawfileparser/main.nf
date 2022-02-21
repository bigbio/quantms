process THERMORAWFILEPARSER {
    tag "$meta.id"
    label 'process_low'
    label 'process_single_thread'

    conda (params.enable_conda ? "conda-forge::mono bioconda::thermorawfileparser=1.3.4" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/thermorawfileparser:1.3.4--ha8f3691_0' :
        'quay.io/biocontainers/thermorawfileparser:1.3.4--ha8f3691_0' }"

    input:
    tuple val(meta), path(rawfile)

    output:
    tuple val(meta), path("*.mzML"), emit: mzmls_converted
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    ThermoRawFileParser.sh -i=${rawfile} -f=2 -o=./ > ${rawfile.baseName}_conversion.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ThermoRawFileParser: \$(ThermoRawFileParser.sh --version)
    END_VERSIONS
    """
}
