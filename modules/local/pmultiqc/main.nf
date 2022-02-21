process PMULTIQC {
    label 'process_high'

    conda (params.enable_conda ? "conda-forge::pandas_schema conda-forge::lzstring bioconda::pmultiqc=0.0.9" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pmultiqc:0.0.9--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/pmultiqc:0.0.9--pyhdfd78af_0"
    }

    input:
    file expdesign
    file 'mzMLs/*'
    file 'quantms_results/*'
    file 'raw_ids/*'

    output:
    path "*.html", emit: ch_pmultiqc_report
    path "*.db", emit: ch_pmultiqc_db
    path "versions.yml", emit: version
    path "*_data", emit: data
    path "*_plots", optional:true, emit: plots

    script:
    def args = task.ext.args ?: ''

    """
    multiqc \\
        --exp_design ${expdesign} \\
        --mzMLs ./mzMLs \\
        --quant_method $params.quant_method \\
        --raw_ids ./raw_ids \\
        ./quantms_results \\
        -o .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pmultiqc: \$(multiqc --pmultiqc_version | sed -e "s/pmultiqc, version //g")
    END_VERSIONS
    """
}
