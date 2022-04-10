process MSSTATS {
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::bioconductor-msstats=4.2.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/bioconductor-msstats:4.2.0--r41h619a076_1"
    } else {
        container "quay.io/biocontainers/bioconductor-msstats:4.2.0--r41h619a076_1"
    }

    input:
    path out_msstats
    path out_mztab_msstats

    output:
    // The generation of the PDFs from MSstats are very unstable, especially with auto-contrasts.
    // And users can easily fix anything based on the csv and the included script -> make optional
    path "*.pdf" optional true
    path "*.mzTab", optional: true, emit: msstats_mztab
    path "*.csv", emit: msstats_csv
    path "*.log", emit: log
    path "versions.yml" , emit: version

    script:
    def args = task.ext.args ?: ''

    """
    msstats_plfq.R \\
        ${out_msstats} \\
        ${out_mztab_msstats} \\
        ${args} \\
        > msstats.log \\
        || echo "Optional MSstats step failed. Please check logs and re-run or do a manual statistical analysis."

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
        bioconductor-msstats: \$(Rscript -e "library(MSstats); cat(as.character(packageVersion('MSstats')))")
    END_VERSIONS
    """
}
