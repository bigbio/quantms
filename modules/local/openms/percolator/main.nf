process PERCOLATOR {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/jpfeuffer/openms-tools-thirdparty-sif:quantms-onnx-v2' :
        'ghcr.io/jpfeuffer/openms-tools-thirdparty:quantms-onnx-v2' }"

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("*_perc.idparquet"), emit: id_files_perc
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"
    def best_per_spectrum_only = params.best_per_spectrum_only ? "-best_per_spectrum_only" : ""
    // PSM-level FDRs run the in-process OpenMS Percolator library; peptide-/protein-level FDRs
    // are only implemented by the external percolator executable (selected automatically by PercolatorAdapter).
    def in_process = !args.contains('-peptide_level_fdrs') && !args.contains('-protein_level_fdrs')

    """
    OMP_NUM_THREADS=$task.cpus PercolatorAdapter \\
        -in ${id_file} \\
        -out ${id_file.baseName}_perc.idparquet \\
        -threads $task.cpus \\
        -subset_max_train $params.subset_max_train \\
        -decoy_pattern $params.decoy_string \\
        -post_processing_tdc \\
        -score_type pep \\
        -score:fdr $params.run_fdr_cutoff \\
        -use_subprocess false \\
        ${best_per_spectrum_only} \\
        $args \\
        2>&1 | tee ${id_file.baseName}_percolator.log

    if [ "${in_process}" = "true" ] && ! grep -q "PSMs in-process" ${id_file.baseName}_percolator.log; then
        echo "ERROR: PercolatorAdapter did not use the in-process Percolator backend. See ${id_file.baseName}_percolator.log." >&2
        exit 1
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PercolatorAdapter: \$(PercolatorAdapter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
        percolator: \$(percolator -h 2>&1 | grep -E '^Percolator version(.*)' | sed 's/Percolator version //g')
    END_VERSIONS
    """
}
