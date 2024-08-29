process MSSTATSTMT {
    tag "$msstatstmt_csv_input.Name"
    label 'process_medium'

    conda "bioconda::bioconductor-msstatstmt=2.10.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-msstatstmt:2.10.0--r43hdfd78af_0' :
        'biocontainers/bioconductor-msstatstmt:2.10.0--r43hdfd78af_0' }"

    input:
    path msstatstmt_csv_input

    output:
    // The generation of the PDFs from MSstatsTMT are very unstable, especially with auto-contrasts.
    // And users can easily fix anything based on the csv and the included script -> make optional
    path "*.pdf" optional true
    path "*.csv", emit: msstats_csv
    path "*.log"
    path "versions.yml" , emit: version

    script:
    def args = task.ext.args ?: ''
    ref_con = params.ref_condition ?: ""

    """
    msstats_tmt.R \\
        ${msstatstmt_csv_input} \\
        "${params.contrasts}" \\
        "${ref_con}" \\
        ${params.msstats_remove_one_feat_prot} \\
        ${params.msstatsiso_useunique_peptide} \\
        ${params.msstatsiso_rmpsm_withfewmea_withinrun} \\
        ${params.msstatsiso_summaryformultiple_psm} \\
        ${params.msstatsiso_summarization_method} \\
        ${params.msstatsiso_global_norm} \\
        ${params.msstatsiso_remove_norm_channel} \\
        ${params.msstatsiso_reference_normalization} \\
        ${msstatstmt_csv_input.baseName} \\
        ${params.msstats_threshold} \\
        ${params.msstats_plot_profile_qc} \\
        $args \\
        2>&1 | tee msstats_tmt.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
        bioconductor-msstatstmt: \$(Rscript -e "library(MSstatsTMT); cat(as.character(packageVersion('MSstatsTMT')))")
    END_VERSIONS
    """
}
