process DIANN_PRELIMINARY_ANALYSIS {
    tag "$mzML.baseName"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'docker.io/biocontainers/diann:v1.8.1_cv1' }"

    input:
    tuple val(meta), file(mzML), file(predict_tsv)

    output:
    path "*.quant", emit: diann_quant
    tuple val(meta), path("*_diann.log"), emit: log
    path "versions.yml", emit: version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    mass_acc_ms1 = meta.precursor_mass_tolerance_unit == "ppm" ? meta.precursor_mass_tolerance : 5
    mass_acc_ms2 = meta.fragment_mass_tolerance_unit == "ppm" ? meta.fragment_mass_tolerance : 13

    mass_acc = params.mass_acc_automatic ? "--quick-mass-acc --individual-mass-acc" : "--mass-acc $mass_acc_ms2 --mass-acc-ms1 $mass_acc_ms1"
    scan_window = params.scan_window_automatic ? "--individual-windows" : "--window $params.scan_window"
    time_corr_only = params.time_corr_only ? "--time-corr-only" : ""

    """
    diann   --lib ${predict_tsv} \\
            --f ${mzML} \\
            --threads ${task.cpus} \\
            --verbose $params.diann_debug \\
            ${scan_window} \\
            --temp ./ \\
            --min-corr $params.min_corr \\
            --corr-diff $params.corr_diff \\
            ${mass_acc} \\
            ${time_corr_only} \\
            $args \\
            2>&1 | tee ${mzML.baseName}_diann.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
