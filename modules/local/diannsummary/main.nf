process DIANNSUMMARY {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'biocontainers/diann:v1.8.1_cv1' }"

    input:
    file(mzMLs)
    val(meta)
    file(empirical_library)
    file("quant/")
    file(fasta)

    output:
    path "diann_report.tsv", emit: main_report
    path "diann_report.pr_matrix.tsv", emit: pr_matrix
    path "diann_report.pg_matrix.tsv", emit: pg_matrix
    path "diann_report.gg_matrix.tsv", emit: gg_matrix
    path "diann_report.unique_genes_matrix.tsv", emit: unique_gene_matrix
    path "diannsummary.log", emit: log
    path "versions.yml", emit: version
    path "diann_version.yml", emit: diann_version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    mass_acc_ms1 = meta.precursor_mass_tolerance_unit == "ppm" ? meta.precursor_mass_tolerance : 5
    mass_acc_ms2 = meta.fragment_mass_tolerance_unit == "ppm" ? meta.fragment_mass_tolerance : 13

    mass_acc = params.mass_acc_automatic ? "--quick-mass-acc --individual-mass-acc" : "--mass-acc $mass_acc_ms2 --mass-acc-ms1 $mass_acc_ms1"
    scan_window = params.scan_window_automatic ? "--individual-windows" : "--window $params.scan_window"
    species_genes = params.species_genes ? "--species-genes": ""

    """
    diann   --lib ${empirical_library} \\
            --fasta ${fasta} \\
            --f ${(mzMLs as List).join(' --f ')} \\
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
            |& tee diannsummary.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS

    cp "versions.yml" "diann_version.yml"
    """
}
