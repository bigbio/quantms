process SPECTRUM_FEATURES {
    tag "$meta.mzml_id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/quantms-rescoring-sif:0.0.13' :
        'ghcr.io/bigbio/quantms-rescoring:0.0.13' }"

    input:
    tuple val(meta), path(id_file), val(search_engine), path(ms_file)

    output:
    tuple val(meta), path("${id_file.baseName}_snr.idXML"), val(search_engine), emit: id_files_snr
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    rescoring spectrum2feature --mzml "${ms_file}" --idxml "${id_file}" --output "${id_file.baseName}_snr.idXML" 2>&1 | tee ${id_file.baseName}_snr_feature.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-rescoring: \$(rescoring --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')
    END_VERSIONS
    """
}
