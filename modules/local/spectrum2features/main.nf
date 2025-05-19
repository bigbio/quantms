process SPECTRUM2FEATURES {
    tag "$meta.mzml_id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quantms-rescoring:0.0.10--pyhdfd78af_0' :
        'biocontainers/quantms-rescoring:0.0.10--pyhdfd78af_0' }"

    // userEmulation settings when docker is specified
    containerOptions = (workflow.containerEngine == 'docker') ? '-u $(id -u) -e "HOME=${HOME}" -v /etc/passwd:/etc/passwd:ro -v /etc/shadow:/etc/shadow:ro -v /etc/group:/etc/group:ro -v $HOME:$HOME' : ''

    input:
    tuple val(meta), path(id_file), path(ms_file)

    output:
    tuple val(meta), path("${id_file.baseName}_snr.idXML"), emit: id_files_snr
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    rescoring spectrum2feature --mzml "${ms_file}" --idxml "${id_file}" --output "${id_file.baseName}_snr.idXML" 2>&1 | tee add_snr_feature.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-rescoring: \$(rescoring --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
    END_VERSIONS
    """
}
