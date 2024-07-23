process DIANNSUMMARY {
    tag "$meta.experiment_id"
    label 'process_high'

    if (params.diann_version == "1.9.beta.1") {
        container 'https://ftp.pride.ebi.ac.uk/pub/databases/pride/resources/tools/ghcr.io-bigbio-diann-1.9.1dev.sif'
    } else {
        container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'docker.io/biocontainers/diann:v1.8.1_cv1' }"
    }

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
    path "diann_report.tsv", emit: main_report
    path "diann_report.pr_matrix.tsv", emit: pr_matrix
    path "diann_report.pg_matrix.tsv", emit: pg_matrix
    path "diann_report.gg_matrix.tsv", emit: gg_matrix
    path "diann_report.unique_genes_matrix.tsv", emit: unique_gene_matrix
    path "diannsummary.log", emit: log
    path "empirical_library.tsv", emit: final_speclib optional true
    path "empirical_library.tsv.speclib", emit: final_tsv_speclib optional true
    path "empirical_library.tsv.skyline.speclib", emit: skyline_speclib optional true
    path "versions.yml", emit: version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    if (params.mass_acc_automatic) {
        mass_acc = '--quick-mass-acc --individual-mass-acc'
    } else if (meta['precursormasstoleranceunit'].toLowerCase().endsWith('ppm') && meta['fragmentmasstoleranceunit'].toLowerCase().endsWith('ppm')){
        mass_acc = "--mass-acc ${meta['fragmentmasstolerance']} --mass-acc-ms1 ${meta['precursormasstolerance']}"
    } else {
        mass_acc = '--quick-mass-acc --individual-mass-acc'
    }

    scan_window = params.scan_window_automatic ? "--individual-windows" : "--window $params.scan_window"
    species_genes = params.species_genes ? "--species-genes": ""

    """
    # Notes: if .quant files are passed, mzml/.d files are not accessed, so the name needs to be passed but files
    # do not need to pe present.

    diann   --lib ${empirical_library} \\
            --fasta ${fasta} \\
            --f ${(ms_files as List).join(' --f ')} \\
            --threads ${task.cpus} \\
            --verbose $params.diann_debug \\
            ${scan_window} \\
            ${mass_acc} \\
            --temp ./quant/ \\
            --relaxed-prot-inf \\
            --pg-level $params.pg_level \\
            ${species_genes} \\
            --use-quant \\
            --matrices \\
            --out diann_report.tsv \\
            --qvalue $params.protein_level_fdr_cutoff \\
            $args \\
            2>&1 | tee diannsummary.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "\\d+\\.\\d+(\\.\\w+)*(\\.[\\d]+)?")
    END_VERSIONS
    """
}
