process PMULTIQC {
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    // pmultiqc is published to bioconda/biocontainers on release; a single image
    // serves Docker (native) and Singularity (via the galaxy depot mirror).
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pmultiqc:0.0.47--pyhdfd78af_0' :
        'biocontainers/pmultiqc:0.0.47--pyhdfd78af_0' }"

    input:
    // Everything the report needs, staged flat under `results/`. Consumers collect
    // their inputs (config, expdesign, quant tables, qpx dataset, logs, ...) into a
    // single channel; all pmultiqc/plugin flags are supplied via `task.ext.args`.
    path multiqc_inputs, stageAs: 'results/*'

    output:
    path "*.html",       emit: ch_pmultiqc_report
    path "*.db",         optional: true, emit: ch_pmultiqc_db
    path "versions.yml", emit: versions
    path "*_data",       emit: data

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    multiqc \\
        -f \\
        ${args} \\
        ./results \\
        -o .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pmultiqc: \$(multiqc --pmultiqc_version | sed -e "s/pmultiqc, version //g")
    END_VERSIONS
    """

    stub:
    """
    touch multiqc_report.html
    mkdir multiqc_report_data

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pmultiqc: \$(multiqc --pmultiqc_version | sed -e "s/pmultiqc, version //g" 2>/dev/null || echo "0.0.47")
    END_VERSIONS
    """
}
