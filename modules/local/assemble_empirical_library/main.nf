process ASSEMBLE_EMPIRICAL_LIBRARY {
    tag "$meta.experiment_id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'biocontainers/diann:v1.8.1_cv1' }"

    input:
    path(mzMLs)
    val(meta)
    path("quant/*")
    path(lib)

    output:
    path "empirical_library.tsv", emit: empirical_library
    path "assemble_empirical_library.log", emit: log
    path "versions.yml", emit: version

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    mass_acc_ms1 = meta.precursor_mass_tolerance_unit == "ppm" ? meta.precursor_mass_tolerance : 5
    mass_acc_ms2 = meta.fragment_mass_tolerance_unit == "ppm" ? meta.fragment_mass_tolerance : 13

    mass_acc = params.mass_acc_automatic ? "--quick-mass-acc --individual-mass-acc" : "--mass-acc $mass_acc_ms2 --mass-acc-ms1 $mass_acc_ms1"
    scan_window = params.scan_window_automatic ? "--individual-windows" : "--window $params.scan_window"

    """
    diann   --f ${(mzMLs as List).join(' --f ')} \\
            --lib ${lib} \\
            --threads ${task.cpus} \\
            --out-lib empirical_library.tsv \\
            --verbose $params.diann_debug \\
            --rt-profiling \\
            --temp ./quant/ \\
            --use-quant \\
            ${mass_acc} \\
            ${scan_window} \\
            --gen-spec-lib \\
            $args \\
            2>&1 | tee assemble_empirical_library.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "(\\d*\\.\\d+\\.\\d+)|(\\d*\\.\\d+)")
    END_VERSIONS
    """
}
