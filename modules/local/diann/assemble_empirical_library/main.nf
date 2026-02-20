process ASSEMBLE_EMPIRICAL_LIBRARY {
    tag "$meta.experiment_id"
    label 'process_low'
    label 'diann'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'docker.io/biocontainers/diann:v1.8.1_cv1' }"

    input:
    // In this step the real files are passed, and not the names
    path(ms_files)
    val(meta)
    path("quant/*")
    path(lib)
    path(diann_config)

    output:
    path "empirical_library.*", emit: empirical_library
    path "assemble_empirical_library.log", emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    // Strip flags that are managed by the pipeline to prevent silent conflicts
    def blocked = ['--no-main-report', '--no-ifs-removal', '--matrices', '--out',
         '--temp', '--threads', '--verbose', '--lib', '--f', '--fasta',
         '--mass-acc', '--mass-acc-ms1', '--window',
         '--individual-mass-acc', '--individual-windows',
         '--out-lib', '--use-quant', '--gen-spec-lib', '--rt-profiling']
    // Sort by length descending so longer flags (e.g. --mass-acc-ms1) are matched before shorter prefixes (--mass-acc)
    blocked.sort { a -> -a.length() }.each { flag ->
        def flagPattern = '(?<=^|\\s)' + java.util.regex.Pattern.quote(flag) + '(?=\\s|\$)(\\s+(?!-{1,2}[a-zA-Z])\\S+)*'
        if (args =~ flagPattern) {
            log.warn "DIA-NN: '${flag}' is managed by the pipeline for ASSEMBLE_EMPIRICAL_LIBRARY and will be stripped."
            args = args.replaceAll(flagPattern, '').trim()
        }
    }

    if (params.mass_acc_automatic) {
        mass_acc = '--individual-mass-acc'
    } else if (meta['precursormasstoleranceunit'].toLowerCase().endsWith('ppm') && meta['fragmentmasstoleranceunit'].toLowerCase().endsWith('ppm')){
        mass_acc = "--mass-acc ${meta['fragmentmasstolerance']} --mass-acc-ms1 ${meta['precursormasstolerance']}"
    } else {
        mass_acc = '--individual-mass-acc'
    }
    scan_window = params.scan_window_automatic ? '--individual-windows' : "--window $params.scan_window"

    """
    # Precursor Tolerance value was: ${meta['precursormasstolerance']}
    # Fragment Tolerance value was: ${meta['fragmentmasstolerance']}
    # Precursor Tolerance unit was: ${meta['precursormasstoleranceunit']}
    # Fragment Tolerance unit was: ${meta['fragmentmasstoleranceunit']}

    ls -lcth

    # Extract --var-mod and --fixed-mod flags from diann_config.cfg (DIA-NN best practice)
    mod_flags=\$(cat ${diann_config} | grep -oP '(--var-mod\\s+\\S+|--fixed-mod\\s+\\S+)' | tr '\\n' ' ')

    diann   --f ${(ms_files as List).join(' --f ')} \\
            --lib ${lib} \\
            --threads ${task.cpus} \\
            --out-lib empirical_library \\
            --verbose $params.diann_debug \\
            --rt-profiling \\
            --temp ./quant/ \\
            --use-quant \\
            ${mass_acc} \\
            ${scan_window} \\
            --gen-spec-lib \\
            \${mod_flags} \\
            $args

    cp report.log.txt assemble_empirical_library.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "\\d+\\.\\d+(\\.\\w+)*(\\.[\\d]+)?")
    END_VERSIONS
    """
}
