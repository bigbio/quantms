// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process PROTEOMICSLFQ {
    label 'process_high'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "bioconda::bumbershoot bioconda::comet-ms bioconda::crux-toolkit=3.2 bioconda::fido=1.0 conda-forge::gnuplot bioconda::luciphor2=2020_04_03 bioconda::msgf_plus=2021.03.22 openms::openms=2.7.0pre bioconda::pepnovo=20101117 bioconda::percolator=3.5 bioconda::sirius-csifingerid=4.0.1 bioconda::thermorawfileparser=1.3.4 bioconda::xtandem=15.12.15.2 openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://ftp.pride.ebi.ac.uk/pride/data/tools/quantms-dev.sif"
    } else {
        container "quay.io/bigbio/quantms:dev"
    }

    input:
    path(mzmls)
    path(id_files)
    path(expdes)
    path(fasta)

    output:
    path "out.mzTab", emit: out_mztab
    path "out.consensusXML", emit: out_consensusXML
    path "out.csv", emit: out_msstats
    path "debug_mergedIDs.idXML", emit: debug_mergedIDs optional true
    path "debug_mergedIDs_inference.idXML", emit: debug_mergedIDs_inference optional true
    path "debug_mergedIDsGreedyResolved.idXML", emit: debug_mergedIDsGreedyResolved optional true
    path "debug_mergedIDsGreedyResolvedFDR.idXML", emit: debug_mergedIDsGreedyResolvedFDR optional true
    path "debug_mergedIDsGreedyResolvedFDRFiltered.idXML", emit: debug_mergedIDsGreedyResolvedFDRFiltered optional true
    path "debug_mergedIDsFDRFilteredStrictlyUniqueResolved.idXML", emit: debug_mergedIDsFDRFilteredStrictlyUniqueResolved optional true
    path "*.log", emit: log
    path "*.version.txt", emit: version

    script:
    def software = getSoftwareName(task.process)
    def msstats_present = params.quantification_method == "feature_intensity" ? '-out_msstats out.csv' : ''
    def triqler_present = (params.quantification_method == "feature_intensity") && (params.add_triqler_output) ? '-out_triqler out_triqler.tsv' : ''
    def decoys_present = (params.quantify_decoys || ((params.quantification_method == "feature_intensity") && params.add_triqler_output)) ? '-PeptideQuantification:quantify_decoys' : ''

    """
    ProteomicsLFQ \\
        -in ${(mzmls as List).join(' ')} \\
        -ids ${(id_files as List).join(' ')} \\
        -design ${expdes} \\
        -fasta ${fasta} \\
        -protein_inference ${params.protein_inference_method} \\
        -quantification_method ${params.quantification_method} \\
        -targeted_only ${params.targeted_only} \\
        -mass_recalibration ${params.mass_recalibration} \\
        -transfer_ids ${params.transfer_ids} \\
        -protein_quantification ${params.protein_quant} \\
        -alignment_order ${params.alignment_order} \\
        -picked_proteinFDR true \\
        -out out.mzTab \\
        -threads ${task.cpus} \\
        ${msstats_present} \\
        ${triqler_present} \\
        ${decoys_present} \\
        -out_cxml out.consensusXML \\
        -proteinFDR ${params.protein_level_fdr_cutoff} \\
        -debug ${params.inf_quant_debug} \\
        $options.args \\
        > proteomicslfq.log

    echo \$(ProteomicsLFQ 2>&1) > ${software}.version.txt
    """
}
