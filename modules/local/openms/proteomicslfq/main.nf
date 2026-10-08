process PROTEOMICSLFQ {
    tag "${expdes.baseName}"
    label 'process_high'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2026.10.04' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2026.10.04' }"

    input:
    path(mzmls)
    path(id_files)
    path(expdes)
    path(fasta, stageAs: 'database/*')
    path(checkpoints, stageAs: 'feature_checkpoints/*')
    val(feature_args)

    output:
    path "${expdes.baseName}_qpx", emit: out_qpx
    path "${expdes.baseName}_openms.consensusXML", emit: out_consensusXML
    path "*msstats_in.csv", emit: out_msstats, optional: true
    path "debug_mergedIDs.idparquet", emit: debug_mergedIDs, optional: true
    path "debug_mergedIDs_inference.idparquet", emit: debug_mergedIDs_inference, optional: true
    path "debug_mergedIDsGreedyResolved.idparquet", emit: debug_mergedIDsGreedyResolved, optional: true
    path "debug_mergedIDsGreedyResolvedFDR.idparquet", emit: debug_mergedIDsGreedyResolvedFDR, optional: true
    path "debug_mergedIDsGreedyResolvedFDRFiltered.idparquet", emit: debug_mergedIDsGreedyResolvedFDRFiltered, optional: true
    path "debug_mergedIDsFDRFilteredStrictlyUniqueResolved.idparquet", emit: debug_mergedIDsFDRFilteredStrictlyUniqueResolved, optional: true
    path "*.log", emit: log
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def db_name = fasta.toString().tokenize("/")[-1]
    def msstats_present = params.quantification_method == "feature_intensity" ? "-out_msstats ${expdes.baseName}_msstats_in.csv" : ""
    // The in-process Thermo RAW reader of the pinned OpenMS image cannot open .raw files through
    // symlinks (as staged by Nextflow), so vendor files are passed by their resolved path.
    // The file name stays the same, so run names still match the experimental design.
    def vendorPath = { f -> f.name ==~ /(?i).*\.(raw|d)/ ? "\$(readlink -f ${f})" : "${f}" }
    def mzml_sorted = mzmls.collect().sort{ a, b -> a.name <=> b.name}
    def id_sorted = id_files.collect().sort{ a, b -> a.name <=> b.name}
    // Combining mode: features were detected per run by PROTEOMICSLFQ_DETECT and are read back from
    // the staged checkpoints. ProteomicsLFQ then takes neither spectra nor identifications.
    def combine = checkpoints instanceof List ? !checkpoints.isEmpty() : checkpoints != null
    def run_inputs = combine ? "-feat_dir feature_checkpoints" : "-in ${mzml_sorted.collect { f -> vendorPath.call(f) }.join(' ')} -ids ${id_sorted.join(' ')}"
    // Bruker .d m/z values are only correct with the Bruker TDF SDK (open-source approximation: up to ~37 ppm off)
    def has_dotd = (combine ? [] : mzml_sorted).any { f -> f.name ==~ /(?i).*\.d/ }

    // Checkpoints record the FASTA by size and modification time; use the same fixed-time local
    // copy as PROTEOMICSLFQ_DETECT (see there).
    """
    cp -L ${fasta} ${db_name}
    touch -m -d @0 ${db_name}

    ProteomicsLFQ \\
        -threads ${task.cpus} \\
        ${run_inputs} \\
        -design ${expdes} \\
        -fasta ${db_name} \\
        ${feature_args} \\
        -protein_inference ${params.protein_inference_method} \\
        -protein_quantification ${params.protein_quant} \\
        -alignment_order ${params.alignment_order} \\
        -psmFDR ${params.psm_level_fdr_cutoff} \\
        -proteinFDR ${params.protein_level_fdr_cutoff} \\
        -picked_proteinFDR ${params.picked_fdr} \\
        -out_cxml ${expdes.baseName}_openms.consensusXML \\
        -out_qpx ${expdes.baseName}_qpx \\
        ${msstats_present} \\
        $args \\
        2>&1 | tee proteomicslfq.log

    if [ "${has_dotd}" = "true" ] && { ! grep -qF 'TIMS calibration: Bruker SDK (m/z + 1/K0)' proteomicslfq.log || grep -F 'TIMS calibration:' proteomicslfq.log | grep -vqF 'Bruker SDK (m/z'; }; then
        echo "ERROR: Bruker .d input was not read with the Bruker TDF SDK m/z calibration (needs the amd64 OpenMS image with libtimsdata). See proteomicslfq.log." >&2
        exit 1
    fi

    rm ${db_name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ProteomicsLFQ: \$(ProteomicsLFQ 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
