process PROTEOMICSLFQ {
    label 'process_high'

    conda (params.enable_conda ? "bioconda::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.8.0--h7ca0330_1' :
        'quay.io/biocontainers/openms:2.8.0--h7ca0330_1' }"

    input:
    path(mzmls)
    path(id_files)
    path(expdes)
    path(fasta)

    output:
    path "out.mzTab", emit: out_mztab
    path "out.consensusXML", emit: out_consensusXML
    path "out_msstats.csv", emit: out_msstats optional true
    path "out_triqler.tsv", emit: out_triqler optional true
    path "debug_mergedIDs.idXML", emit: debug_mergedIDs optional true
    path "debug_mergedIDs_inference.idXML", emit: debug_mergedIDs_inference optional true
    path "debug_mergedIDsGreedyResolved.idXML", emit: debug_mergedIDsGreedyResolved optional true
    path "debug_mergedIDsGreedyResolvedFDR.idXML", emit: debug_mergedIDsGreedyResolvedFDR optional true
    path "debug_mergedIDsGreedyResolvedFDRFiltered.idXML", emit: debug_mergedIDsGreedyResolvedFDRFiltered optional true
    path "debug_mergedIDsFDRFilteredStrictlyUniqueResolved.idXML", emit: debug_mergedIDsFDRFilteredStrictlyUniqueResolved optional true
    path "*.log", emit: log
    path "versions.yml", emit: version

    script:
    def args = task.ext.args ?: ''
    def msstats_present = params.quantification_method == "feature_intensity" ? '-out_msstats out_msstats.csv' : ''
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
        $args \\
        |& tee proteomicslfq.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ProteomicsLFQ: \$(ProteomicsLFQ 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
