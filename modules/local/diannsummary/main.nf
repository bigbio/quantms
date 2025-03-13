process DIANNSUMMARY {
    tag "$meta.experiment_id"
    label 'process_high'
    label 'diann'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'docker.io/biocontainers/diann:v1.8.1_cv1' }"

    input:
    // Note that the files are passed as names and not paths, this prevents them from being staged
    // in the directory
    val(ms_files)
    val(meta)
    path(empirical_library)
    // The quant path is passed, and diann will use the files in the quant directory instead
    // of the ones passed in ms_files.
    path("quant/")
    path(fasta)

    output:
    // DIA-NN 2.0 don't return report in tsv format
    path "diann_report.tsv", emit: main_report optional true
    path "diann_report.parquet", emit: report_parquet optional true
    path "diann_report.manifest.txt", emit: report_manifest optional true
    path "diann_report.protein_description.tsv", emit: protein_description optional true
    path "diann_report.stats.tsv", emit: report_stats
    path "diann_report.pr_matrix.tsv", emit: pr_matrix
    path "diann_report.pg_matrix.tsv", emit: pg_matrix
    path "diann_report.gg_matrix.tsv", emit: gg_matrix
    path "diann_report.unique_genes_matrix.tsv", emit: unique_gene_matrix
    path "diannsummary.log", emit: log

    // Different library files format are exported due to different DIA-NN versions
    path "empirical_library.tsv", emit: final_speclib optional true
    path "empirical_library.tsv.skyline.speclib", emit: skyline_speclib optional true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    scan_window = params.scan_window_automatic ? "--individual-windows" : "--window $params.scan_window"
    species_genes = params.species_genes ? "--species-genes": ""
    report_decoys = params.diann_report_decoys ? "--report-decoys": ""
    diann_export_xic = params.diann_export_xic ? "--xic": ""

    """
    # Notes: if .quant files are passed, mzml/.d files are not accessed, so the name needs to be passed but files
    # do not need to pe present.

    diann   --lib ${empirical_library} \\
            --fasta ${fasta} \\
            --f ${(ms_files as List).join(' --f ')} \\
            --threads ${task.cpus} \\
            --verbose $params.diann_debug \\
            --temp ./quant/ \\
            --relaxed-prot-inf \\
            --pg-level $params.pg_level \\
            ${species_genes} \\
            --use-quant \\
            --matrices \\
            --out diann_report.tsv \\
            --qvalue $params.protein_level_fdr_cutoff \\
            ${report_decoys} \\
            ${diann_export_xic} \\
            $args

    cp diann_report.log.txt diannsummary.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "\\d+\\.\\d+(\\.\\w+)*(\\.[\\d]+)?")
    END_VERSIONS
    """
}
