process PRELIMINARY_ANALYSIS {
    tag "$ms_file.baseName"
    label 'process_high'
    label 'diann'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'docker.io/biocontainers/diann:v1.8.1_cv1' }"

    input:
    tuple val(meta), path(ms_file), path(predict_library)
    path(diann_config)

    output:
    path "*.quant", emit: diann_quant
    tuple val(meta), path("*_diann.log"), emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    // Strip flags that are managed by the pipeline to prevent silent conflicts
    def blocked = ['--use-quant', '--gen-spec-lib', '--out-lib', '--matrices', '--out',
         '--temp', '--threads', '--verbose', '--lib', '--f', '--fasta',
         '--mass-acc', '--mass-acc-ms1', '--window',
         '--quick-mass-acc', '--min-corr', '--corr-diff', '--time-corr-only']
    // Sort by length descending so longer flags (e.g. --mass-acc-ms1) are matched before shorter prefixes (--mass-acc)
    blocked.sort { a -> -a.length() }.each { flag ->
        def flagPattern = '(?<=^|\\s)' + java.util.regex.Pattern.quote(flag) + '(?=\\s|\$)(\\s+(?!-{1,2}[a-zA-Z])\\S+)*'
        if (args =~ flagPattern) {
            log.warn "DIA-NN: '${flag}' is managed by the pipeline for PRELIMINARY_ANALYSIS and will be stripped."
            args = args.replaceAll(flagPattern, '').trim()
        }
    }

    // Performance flags for preliminary analysis calibration step
    quick_mass_acc = params.quick_mass_acc ? "--quick-mass-acc" : ""
    performance_flags = params.performance_mode ? "--min-corr 2 --corr-diff 1 --time-corr-only" : ""

    // I am using here the ["key"] syntax, since the preprocessed meta makes
    // was evaluating to null when using the dot notation.

    if (params.mass_acc_automatic) {
        mass_acc = ""
    } else if (meta['precursormasstoleranceunit'].toLowerCase().endsWith('ppm') && meta['fragmentmasstoleranceunit'].toLowerCase().endsWith('ppm')){
        mass_acc = "--mass-acc ${meta['fragmentmasstolerance']} --mass-acc-ms1 ${meta['precursormasstolerance']}"
    } else {
        log.info "Warning: DIA-NN only supports ppm unit tolerance for MS1 and MS2. Falling back to `mass_acc_automatic`=`true` to automatically determine the tolerance by DIA-NN!"
        mass_acc = ""
    }

    // Notes: Use double quotes for params, so that it is escaped in the shell.
    scan_window = params.scan_window_automatic ? '' : "--window $params.scan_window"

    """
    # Precursor Tolerance value was: ${meta['precursormasstolerance']}
    # Fragment Tolerance value was: ${meta['fragmentmasstolerance']}
    # Precursor Tolerance unit was: ${meta['precursormasstoleranceunit']}
    # Fragment Tolerance unit was: ${meta['fragmentmasstoleranceunit']}

    # Final mass accuracy is '${mass_acc}'

    # Extract --var-mod and --fixed-mod flags from diann_config.cfg (DIA-NN best practice)
    mod_flags=\$(cat ${diann_config} | grep -oP '(--var-mod\\s+\\S+|--fixed-mod\\s+\\S+)' | tr '\\n' ' ')

    diann   --lib ${predict_library} \\
            --f ${ms_file} \\
            --threads ${task.cpus} \\
            --verbose $params.diann_debug \\
            ${scan_window} \\
            --temp ./ \\
            ${mass_acc} \\
            ${quick_mass_acc} \\
            ${performance_flags} \\
            \${mod_flags} \\
            $args

    cp report.log.txt ${ms_file.baseName}_diann.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "\\d+\\.\\d+(\\.\\w+)*(\\.[\\d]+)?")
    END_VERSIONS
    """
}
