// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process PROTEINQUANTIFIER {
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms:2.6.0--h4afb90d_0"
    } else {
        container "quay.io/biocontainers/openms:2.6.0--h4afb90d_0"
    }

    input:
    path epi_filt_resolve
    path pro_quant_exp

    output:
    path "protein_out.csv", emit: protein_out
    path "peptide_out.csv", emit: peptide_out
    path "*.mzTab", emit: out_mztab
    path "*.log"
    path "*.version.txt", emit: version

    script:
    def software = getSoftwareName(task.process)

    """
    ProteinQuantifier \\
        -in ${epi_filt_resolve} \\
        -design ${pro_quant_exp} \\
        -out protein_out.csv \\
        -peptide_out peptide_out.csv \\
        -top $options.top \\
        -average $options.average \\
        $options.include_all \\
        $options.fix_peptides \\
        -best_charge_and_fraction \\
        -ratios \\
        -threads $task.cpus \\
        $options.normalize \\
        -debug 100 \\
        > pro_quant.log

    echo \$(ProteinQuantifier --version 2>&1) > ${software}.version.txt
    """
}
