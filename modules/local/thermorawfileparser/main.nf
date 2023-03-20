process THERMORAWFILEPARSER {
    tag "$meta.mzml_id"
    label 'process_low'
    label 'process_single'
    label 'error_retry'

    conda "conda-forge::mono bioconda::thermorawfileparser=1.3.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/thermorawfileparser:1.3.4--ha8f3691_0' :
        'quay.io/biocontainers/thermorawfileparser:1.3.4--ha8f3691_0' }"

    stageInMode {
        if (task.attempt == 1) {
            if (executor == "awsbatch") {
                'symlink'
            } else {
                'link'
            }
        } else if (task.attempt == 2) {
            if (executor == "awsbatch") {
                'copy'
            } else {
                'symlink'
            }
        } else {
            'copy'
        }
    }

    input:
    tuple val(meta), path(rawfile)

    output:
    tuple val(meta), path("*.mzML"), emit: mzmls_converted
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    ThermoRawFileParser.sh -i=${rawfile} -f=2 -o=./ 2>&1 | tee ${rawfile.baseName}_conversion.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ThermoRawFileParser: \$(ThermoRawFileParser.sh --version)
    END_VERSIONS
    """
}
