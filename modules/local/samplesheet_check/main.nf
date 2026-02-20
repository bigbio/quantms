process SAMPLESHEET_CHECK {

    tag "$input_file"
    label 'process_tiny'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quantms-utils:0.0.24--pyh7e72e81_0' :
        'biocontainers/quantms-utils:0.0.24--pyh7e72e81_0' }"

    input:
    path input_file
    val validate_ontologies

    output:
    path "*.log", emit: log
    path "*.sdrf.tsv", includeInputs: true, emit: checked_file
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def string_skip_sdrf_validation = params.validate_ontologies == false ? "--skip_sdrf_validation" : ""
    def string_skip_ms_validation = params.skip_ms_validation == true ? "--skip_ms_validation" : ""
    def string_skip_factor_validation = params.skip_factor_validation == true ? "--skip_factor_validation" : ""
    def string_skip_experimental_design_validation = params.skip_experimental_design_validation == true ? "--skip_experimental_design_validation" : ""
    def string_use_ols_cache_only = params.use_ols_cache_only == true ? "--use_ols_cache_only" : ""

    """
    # Get basename and create output filename
    BASENAME=\$(basename "${input_file}")
    # Remove .sdrf.tsv, .sdrf.csv, or .sdrf extension (in that order to match longest first)
    BASENAME=\$(echo "\$BASENAME" | sed -E 's/\\.sdrf\\.(tsv|csv)\$//' | sed -E 's/\\.sdrf\$//')
    OUTPUT_FILE="\${BASENAME}.sdrf.tsv"

    # Convert CSV to TSV if needed using pandas
    if [[ "${input_file}" == *.csv ]]; then
        python -c "import pandas as pd; df = pd.read_csv('${input_file}'); df.to_csv('\$OUTPUT_FILE', sep='\\t', index=False)"
    elif [[ "${input_file}" != "\$OUTPUT_FILE" ]]; then
        cp "${input_file}" "\$OUTPUT_FILE"
    fi

    quantmsutilsc checksamplesheet --exp_design "\$OUTPUT_FILE" --is_sdrf \\
    ${string_skip_sdrf_validation} \\
    ${string_skip_ms_validation} \\
    ${string_skip_factor_validation} \\
    ${string_skip_experimental_design_validation} \\
    ${string_use_ols_cache_only} \\
    $args \\
    2>&1 | tee input_check.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-utils: \$(pip show quantms-utils | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
