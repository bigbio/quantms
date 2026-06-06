process EXTRACTPSMFEATURES {
    tag "$meta.mzml_id"
    label 'process_very_low'
    label 'process_single'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:latest' :
        'ghcr.io/openms/openms-tools-thirdparty:latest' }"

    input:
    tuple val(meta), path(id_files)

    output:
    tuple val(meta), path("*_feat.idparquet"), emit: id_files_feat
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: ''

    """
    PSMFeatureExtractor \\
        -in ${id_files.join(' ')} \\
        -out ${meta.mzml_id}_feat.idparquet \\
        -threads $task.cpus \\
        -multiple_search_engines \\
        -skip_db_check \\
        -impute \\
        $args \\
        2>&1 | tee ${meta.mzml_id}_extract_psm_feature.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PSMFeatureExtractor: \$(PSMFeatureExtractor 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}