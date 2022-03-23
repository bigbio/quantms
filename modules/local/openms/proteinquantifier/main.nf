process PROTEINQUANTIFIER {
    label 'process_medium'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

    input:
    path epi_filt_resolve
    path pro_quant_exp

    output:
    path "protein_out.csv", emit: protein_out
    path "peptide_out.csv", emit: peptide_out
    path "*.mzTab", emit: out_mztab
    path "*.log"
    path "versions.yml", emit: version

    script:
    def args = task.ext.args ?: ''

    include_all = params.include_all ? "-include_all" : ""
    fix_peptides = params.fix_peptides ? "-fix_peptides" : ""
    normalize = params.normalize ? "-consensus:normalize" : ""

    """
    ProteinQuantifier \\
        -in ${epi_filt_resolve} \\
        -design ${pro_quant_exp} \\
        -out protein_out.csv \\
        -mztab out.mzTab \\
        -peptide_out peptide_out.csv \\
        -top $params.top \\
        -average $params.average \\
        ${include_all} \\
        ${fix_peptides} \\
        -ratios \\
        -threads $task.cpus \\
        ${normalize} \\
        -debug $params.debug \\
        > pro_quant.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ProteinQuantifier: \$(ProteinQuantifier 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
