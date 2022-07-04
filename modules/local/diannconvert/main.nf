process DIANNCONVERT {
    tag "$exp_design.Name"
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::pandas_schema bioconda::sdrf-pipelines=0.0.21" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.21--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/sdrf-pipelines:0.0.21--pyhdfd78af_0"
    }

    input:
    path(report)
    path(exp_design)
    path(report_pg)
    path(report_pr)
    path(report_unique_gene)
    val(meta)
    path(fasta)
    val(charge)
    val(missed_cleavages)

    output:
    path "*msstats_in.csv", emit: out_msstats
    path "*triqler_in.tsv", emit: out_triqler
    path "*.mztab", emit: out_mztab
    path "versions.yml", emit: version

    script:
    def args = task.ext.args ?: ''
    def dia_params = [meta.fragmentmasstolerance, meta.fragmentmasstoleranceunit, meta.precursormasstolerance, 
                meta.precursormasstoleranceunit, meta.enzyme, meta.fixedmodifications, meta.variablemodifications].join(';')

    """
    diann_convert.py convert \\
        --diann_report "${report}" \\
        --exp_design "${exp_design}" \\
        --pg_matrix "${report_pg}" \\
        --pr_matrix "${report_pr}" \\
        --unique_matrix "${report_unique_gene}" \\
        --dia_params "${dia_params}" \\
        --fasta "${fasta}" \\
        --charge ${charge} \\
        --missed_cleavages ${missed_cleavages} \\
        --qvalue_threshold ${params.protein_level_fdr_cutoff} \\
        |& tee convert_report.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(echo "0.0.21")
    END_VERSIONS
    """
}
