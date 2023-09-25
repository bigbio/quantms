process MSSTATSCONVERTER {
    tag "$exp_file.Name"
    label 'process_low'

    conda "openms::openms-thirdparty=3.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'ghcr.io/openms/openms-executables-sif:latest' :
        'ghcr.io/openms/openms-executables:latest' }"

    input:
    path consensusXML
    path exp_file
    val quant_method

    output:
    path "*_msstats_in.csv", emit: out_msstats
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''

    """
    MSstatsConverter \\
        -in ${consensusXML} \\
        -in_design ${exp_file} \\
        -method ${quant_method} \\
        -out ${exp_file.baseName}_msstats_in.csv \\
        $args \\
        2>&1 | tee MSstatsConverter.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MSstatsConverter: \$(MSstatsConverter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
