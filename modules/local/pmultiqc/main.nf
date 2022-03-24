process PMULTIQC {
    label 'process_high'

    conda (params.enable_conda ? "conda-forge::pandas_schema conda-forge::lzstring bioconda::pmultiqc=0.0.10" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pmultiqc:0.0.10--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/pmultiqc:0.0.10--pyhdfd78af_0"
    }

    input:
    path expdesign
    path 'mzMLs/*'
    path 'results/*'
    path 'raw_ids/*'
    path quantms_log

    output:
    path "*.html", emit: ch_pmultiqc_report
    path "*.db", emit: ch_pmultiqc_db
    path "versions.yml", emit: versions
    path "*_data", emit: data
    path "*_plots", optional:true, emit: plots

    script:
    def args = task.ext.args ?: ''

    """
    multiqc \\
        --exp_design ${expdesign} \\
        --mzMLs ./mzMLs \\
        --raw_ids ./raw_ids \\
        ./results \\
        -o .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pmultiqc: \$(multiqc --pmultiqc_version | sed -e "s/pmultiqc, version //g")
    END_VERSIONS
    """
}
