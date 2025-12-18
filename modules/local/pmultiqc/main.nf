process PMULTIQC {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pmultiqc:0.0.39--pyhdfd78af_0' :
        'biocontainers/pmultiqc:0.0.39--pyhdfd78af_0' }"

    input:
    path 'results/*'
    path quantms_log

    output:
    path "*.html", emit: ch_pmultiqc_report
    path "*.db", optional: true, emit: ch_pmultiqc_db
    path "versions.yml", emit: versions
    path "*_data", emit: data

    script:
    def args = task.ext.args ?: ''
    def disable_pmultiqc = (params.enable_pmultiqc) && (params.export_mztab) ? "--quantms_plugin" : ""
    def disable_table_plots = (params.enable_pmultiqc) && (params.skip_table_plots) ? "--disable_table" : ""
    def disable_idxml_index = (params.enable_pmultiqc) && (params.pmultiqc_idxml_skip) ? "--ignored_idxml" : ""
    def contaminant_affix = params.contaminant_string ? "--contaminant_affix ${params.contaminant_string}" : ""

    """
    set -x
    set -e

    # leaving here to ease debugging
    ls -lcth *

    cat results/*openms_design.tsv

    multiqc \\
        -f \\
        ${disable_pmultiqc} \\
        --config ./results/multiqc_config.yml \\
        ${args} \\
        ${disable_table_plots} \\
        ${disable_idxml_index} \\
        ${contaminant_affix} \\
        --quantification_method $params.quantification_method \\
        ./results \\
        -o .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pmultiqc: \$(multiqc --pmultiqc_version | sed -e "s/pmultiqc, version //g")
    END_VERSIONS
    """
}
