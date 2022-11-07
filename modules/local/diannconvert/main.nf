process DIANNCONVERT {
    tag "$meta.experiment_id"
    label 'process_medium'

    conda (params.enable_conda ? "conda-forge::pandas_schema conda-forge::lzstring bioconda::pmultiqc=0.0.17" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pmultiqc:0.0.17--pyhdfd78af_0"
    } else {
        container "quay.io/biocontainers/pmultiqc:0.0.17--pyhdfd78af_0"
    }

    input:
    path(report)
    path(exp_design)
    path(report_pg)
    path(report_pr)
    path(mzml_information)
    val(meta)
    path(fasta)
    path("version/versions.yaml")

    output:
    path "*msstats_in.csv", emit: out_msstats
    path "*triqler_in.tsv", emit: out_triqler
    path "*.mztab", emit: out_mztab
    path "versions.yml", emit: version

    exec:
        log.info "DIANNCONVERT is based on the output of DIA-NN 1.8.1, other versions of DIA-NN do not support mzTab conversion."

    script:
    def args = task.ext.args ?: ''
    def dia_params = [meta.fragmentmasstolerance,meta.fragmentmasstoleranceunit,meta.precursormasstolerance,
                        meta.precursormasstoleranceunit,meta.enzyme,meta.fixedmodifications,meta.variablemodifications].join(';')

    """
    diann_convert.py convert \\
        --diann_report "${report}" \\
        --exp_design "${exp_design}" \\
        --pg_matrix "${report_pg}" \\
        --pr_matrix "${report_pr}" \\
        --mzml_info "${mzml_information}" \\
        --dia_params "${dia_params}" \\
        --diann_version ./version/versions.yaml \\
        --fasta "${fasta}" \\
        --charge $params.max_precursor_charge \\
        --missed_cleavages $params.allowed_missed_cleavages \\
        --qvalue_threshold $params.protein_level_fdr_cutoff \\
        |& tee convert_report.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(pip show pyopenms | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
