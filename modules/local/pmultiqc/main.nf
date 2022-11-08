process PMULTIQC {
    label 'process_high'

    conda (params.enable_conda ? "conda-forge::pandas_schema conda-forge::lzstring bioconda::pmultiqc=0.0.17" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pmultiqc:0.0.17--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/pmultiqc:0.0.17--pyhdfd78af_0"
    }

    input:
    path 'results/*'
    path quantms_log

    output:
    path "*.html", emit: ch_pmultiqc_report
    path "*.db", optional: true, emit: ch_pmultiqc_db
    path "versions.yml", emit: versions
    path "*_data", emit: data
    path "*_plots", optional: true, emit: plots

    script:
    def args = task.ext.args ?: ''
    def disable_pmultiqc = (params.enable_pmultiqc) && (params.export_mztab) ? "" : "--disable_plugin"
    def disable_table_plots = (params.enable_pmultiqc) && (params.skip_table_plots) ? "--disable_table" : ""

    """
    multiqc \\
        -f \\
        --config ./results/multiqc_config.yml \\
        ${args} \\
        ${disable_pmultiqc} \\
        ${disable_table_plots} \\
        --quantification_method $params.quantification_method \\
        ./results \\
        -o .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pmultiqc: \$(multiqc --pmultiqc_version | sed -e "s/pmultiqc, version //g")
    END_VERSIONS
    """
}
