process PROTEINQUANTIFIER {
    tag "${pro_quant_exp.baseName}"
    label 'process_medium'

    conda "bioconda::openms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.9.1--h135471a_0' :
        'quay.io/biocontainers/openms:2.9.1--h135471a_0' }"

    input:
    path epi_filt_resolve
    path pro_quant_exp

    output:
    path "*protein_openms.csv", emit: protein_out
    path "*peptide_openms.csv", emit: peptide_out
    path "*.mzTab", optional: true, emit: out_mztab
    path "*.log"
    path "versions.yml", emit: version

    script:
    def args = task.ext.args ?: ''

    include_all = params.include_all ? "-top:include_all" : ""
    fix_peptides = params.fix_peptides ? "-fix_peptides" : ""
    normalize = params.normalize ? "-consensus:normalize" : ""
    export_mztab = params.export_mztab ? "-mztab ${pro_quant_exp.baseName}_openms.mzTab" : ""

    """
    ProteinQuantifier \\
        -method 'top' \\
        -in ${epi_filt_resolve} \\
        -design ${pro_quant_exp} \\
        -out ${pro_quant_exp.baseName}_protein_openms.csv \\
        ${export_mztab} \\
        -peptide_out ${pro_quant_exp.baseName}_peptide_openms.csv \\
        -top:N $params.top \\
        -top:aggregate $params.average \\
        ${include_all} \\
        ${fix_peptides} \\
        -ratios \\
        -threads $task.cpus \\
        ${normalize} \\
        $args \\
        2>&1 | tee pro_quant.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ProteinQuantifier: \$(ProteinQuantifier 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -c 1-50)
    END_VERSIONS
    """
}
