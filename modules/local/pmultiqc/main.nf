// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process PMULTIQC {
    label 'process_high'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

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
    path "*.version.txt", emit: version
    path "*_data", emit: data
    path "*_plots", optional:true, emit: plots

    script:
    def software = getSoftwareName(task.process)
    """
    multiqc \\
        --exp_design ${expdesign} \\
        --mzMLs ./mzMLs \\
        --quant_method $params.quant_method \\
        --raw_ids ./raw_ids \\
        ./quantms_results \\
        -o .
    multiqc --pmultiqc_version | sed -e "s/pmultiqc, version //g" > ${software}.version.txt

    """
}
