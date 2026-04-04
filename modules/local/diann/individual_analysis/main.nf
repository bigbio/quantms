process INDIVIDUAL_ANALYSIS {
    tag "$ms_file.baseName"
    label 'process_high'
    label 'diann'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.1_cv1/diann_v1.8.1_cv1.img' :
        'docker.io/biocontainers/diann:v1.8.1_cv1' }"

    input:
    tuple val(meta), path(ms_file), path(fasta), path(diann_log), path(library)
    path(diann_config)

    output:
    path "*.quant", emit: diann_quant
    path "*_final_diann.log", emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    // Strip flags that are managed by the pipeline to prevent silent conflicts
    def blocked = ['--use-quant', '--gen-spec-lib', '--out-lib', '--matrices', '--out', '--rt-profiling',
         '--temp', '--threads', '--verbose', '--lib', '--f', '--fasta',
         '--mass-acc', '--mass-acc-ms1', '--window',
         '--no-ifs-removal', '--no-main-report', '--relaxed-prot-inf', '--pg-level']
    // Sort by length descending so longer flags (e.g. --mass-acc-ms1) are matched before shorter prefixes (--mass-acc)
    blocked.sort { a -> -a.length() }.each { flag ->
        def flagPattern = '(?<=^|\\s)' + java.util.regex.Pattern.quote(flag) + '(?=\\s|\$)(\\s+(?!-{1,2}[a-zA-Z])\\S+)*'
        if (args =~ flagPattern) {
            log.warn "DIA-NN: '${flag}' is managed by the pipeline for INDIVIDUAL_ANALYSIS and will be stripped."
            args = args.replaceAll(flagPattern, '').trim()
        }
    }

    // Warn about flags that override pipeline-computed calibration values (not blocked, but may change behaviour)
    ['--individual-windows', '--individual-mass-acc'].each { flag ->
        if (args.contains(flag)) {
            log.warn "DIA-NN: '${flag}' overrides the mass accuracy / scan window values computed by the PRELIMINARY_ANALYSIS step. This may change pipeline behaviour."
        }
    }

    scan_window = params.scan_window

    if (params.mass_acc_automatic | params.scan_window_automatic) {
        mass_acc_ms2 = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 11 | tr -cd \"[0-9]\")"
        scan_window = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 19 | tr -cd \"[0-9]\")"
        mass_acc_ms1 = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 15 | tr -cd \"[0-9]\")"
    } else if (meta['precursormasstoleranceunit'].toLowerCase().endsWith('ppm') && meta['fragmentmasstoleranceunit'].toLowerCase().endsWith('ppm')) {
        mass_acc_ms1 = meta["precursormasstolerance"]
        mass_acc_ms2 = meta["fragmentmasstolerance"]
    } else {
        mass_acc_ms2 = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 11 | tr -cd \"[0-9]\")"
        scan_window = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 19 | tr -cd \"[0-9]\")"
        mass_acc_ms1 = "\$(cat ${diann_log} | grep \"Averaged recommended settings\" | cut -d ' ' -f 15 | tr -cd \"[0-9]\")"
    }

    """
    # Extract --var-mod and --fixed-mod flags from diann_config.cfg (DIA-NN best practice)
    mod_flags=\$(cat ${diann_config} | grep -oP '(--var-mod\\s+\\S+|--fixed-mod\\s+\\S+)' | tr '\\n' ' ')

    diann   --lib ${library} \\
            --f ${ms_file} \\
            --fasta ${fasta} \\
            --threads ${task.cpus} \\
            --verbose $params.diann_debug \\
            --temp ./ \\
            --mass-acc ${mass_acc_ms2} \\
            --mass-acc-ms1 ${mass_acc_ms1} \\
            --window ${scan_window} \\
            --no-ifs-removal \\
            --no-main-report \\
            --relaxed-prot-inf \\
            --pg-level $params.pg_level \\
            \${mod_flags} \\
            $args

    cp report.log.txt ${ms_file.baseName}_final_diann.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DIA-NN: \$(diann 2>&1 | grep "DIA-NN" | grep -oP "\\d+\\.\\d+(\\.\\w+)*(\\.[\\d]+)?")
    END_VERSIONS
    """
}
