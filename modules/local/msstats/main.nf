process MSSTATS {
    tag "$out_msstats.Name"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::bioconductor-msstats=4.2.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/bioconductor-msstats:4.2.0--r41h619a076_1"
    } else {
        container "quay.io/biocontainers/bioconductor-msstats:4.2.0--r41h619a076_1"
    }

    input:
    path out_msstats

    output:
    // The generation of the PDFs from MSstats are very unstable, especially with auto-contrasts.
    // And users can easily fix anything based on the csv and the included script -> make optional
    path "*.pdf" optional true
    path "*.csv", emit: msstats_csv
    path "*.log", emit: log
    path "versions.yml" , emit: version

    script:
    def args = task.ext.args ?: ''
    ref_con = params.ref_condition ?: ""

    """
    msstats_plfq.R \\
        ${out_msstats} \\
        ${params.contrasts} \\
        "${ref_con}" \\
        ${params.msstats_remove_one_feat_prot} \\
        ${params.msstatslfq_removeFewMeasurements} \\
        ${params.msstatslfq_feature_subset_protein} \\
        ${params.msstatslfq_quant_summary_method} \\
        $args \\
        > msstats.log \\
        || echo "Optional MSstats step failed. Please check logs and re-run or do a manual statistical analysis."

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
        bioconductor-msstats: \$(Rscript -e "library(MSstats); cat(as.character(packageVersion('MSstats')))")
    END_VERSIONS
    """
}
