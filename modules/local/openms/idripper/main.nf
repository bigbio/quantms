process IDRIPPER {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
    tuple val(meta), path(id_file), val(qval_score)

    output:
    val(meta), emit: meta
    path("*.idXML"), emit: id_rippers
    val("MS:1001491"), emit: qval_score
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    if (id_file.baseName.contains('sage')){
        pattern = "_sage_perc.idXML"
    } else if (id_file.baseName.contains('comet')){
        pattern = "_comet_perc.idXML"
    } else {
        pattern = "_msgf_perc.idXML"
    }

    """
    IDRipper \\
        -in ${id_file} \\
        -threads $task.cpus \\
        -out ./ \\
        -split_ident_runs \\
        $args \\
        2>&1 | tee ${prefix}_idripper.log

    for i in `ls | grep -v \"_perc.idXML\$\" | grep \".idXML\$\"`
    do
        mv \$i `ls \"\$i\" |awk -F \".\" \'{print \$1\"${pattern}\"}\'`
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IDRipper: \$(IDRipper 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
//
