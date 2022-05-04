process MSSTATSTMT {
    tag "$out_msstats_tmt.Name"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::bioconductor-msstatstmt=2.2.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/bioconductor-msstatstmt:2.2.0--r41hdfd78af_0"
    } else {
        container "quay.io/biocontainers/bioconductor-msstatstmt:2.2.0--r41hdfd78af_0"
    }

    input:
    path out_msstats_tmt

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
        ${out_msstats_tmt} \\
        ${params.contrasts} \\
        "${ref_con}" \\
        ${params.msstats_remove_one_feat_prot} \\
        ${params.msstatsiso_useunique_peptide} \\
        ${params.msstatsiso_rmpsm_withfewmea_withinrun} \\
        ${params.msstatsiso_summaryformultiple_psm} \\
        ${params.msstatsiso_summarization_method} \\
        ${params.msstatsiso_global_norm} \\
        ${params.msstatsiso_remove_norm_channel} \\
        ${params.msstatsiso_reference_normalization} \\
        $args \\
        > msstats_tmt.log \\
        || echo "Optional MSstatsTMT step failed. Please check logs and re-run or do a manual statistical analysis."


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MSstatsTMT: \$(echo "2.2.0")
    END_VERSIONS
    """
}
