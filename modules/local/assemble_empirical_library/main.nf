process ASSEMBLE_EMPIRICAL_LIBRARY {
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'biocontainers/diann:v1.8.1_cv1' }"

    input:
    path(mzMLs)
    path("quant/*")
    path(lib)
    path(diann_config)

    output:
    path "empirical_library.tsv", emit: empirical_library
    path "assemble_empirical_library.log", emit: log
    path "versions.yml", emit: version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    min_pr_mz = params.min_pr_mz ? "--min-pr-mz $params.min_pr_mz":""
    max_pr_mz = params.max_pr_mz ? "--max-pr-mz $params.max_pr_mz":""
    min_fr_mz = params.min_fr_mz ? "--min-fr-mz $params.min_fr_mz":""
    max_fr_mz = params.max_fr_mz ? "--max-fr-mz $params.max_fr_mz":""

    mass_acc = params.mass_acc_automatic ? "--quick-mass-acc --individual-mass-acc" : "--mass-acc $params.mass_acc_ms2 --mass-acc-ms1 $params.mass_acc_ms1"
    scan_window = params.scan_window_automatic ? "--individual-windows" : "--window $params.scan_window"

    """
    diann   "echo \$(cat ${diann_config})" \\
            --f ${(mzMLs as List).join(' --f ')} \\
            --lib ${lib} \\
            ${min_pr_mz} \\
            ${max_pr_mz} \\
            ${min_fr_mz} \\
            ${max_fr_mz} \\
            --threads ${task.cpus} \\
            --out-lib empirical_library.tsv \\
            --missed-cleavages $params.allowed_missed_cleavages \\
            --min-pep-len $params.min_peptide_length \\
            --max-pep-len $params.max_peptide_length \\
            --min-pr-charge $params.min_precursor_charge \\
            --max-pr-charge $params.max_precursor_charge \\
            --var-mods $params.max_mods \\
            --verbose $params.diann_debug \\
            --rt-profiling \\
            --temp ./quant/ \\
            --use-quant \\
            ${mass_acc} \\
            ${scan_window} \\
            --gen-spec-lib \\
            $args \\
            |& tee assemble_empirical_library.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
