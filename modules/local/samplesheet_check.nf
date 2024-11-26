process SAMPLESHEET_CHECK {

    tag "$input_file"
    label 'process_single'

    conda "bioconda::quantms-utils=0.0.15"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quantms-utils:0.0.15--pyhdfd78af_0' :
        'biocontainers/quantms-utils:0.0.15--pyhdfd78af_0' }"

    input:
    path input_file
    val is_sdrf
    val validate_ontologies

    output:
    path "*.log", emit: log
    path "${input_file}", emit: checked_file
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-core/quantms/bin/
    // TODO validate experimental design file
    def args = task.ext.args ?: ''
    def string_skip_sdrf_validation = params.validate_ontologies == false ? "--skip_sdrf_validation" : ""
    def string_skip_ms_validation = params.skip_ms_validation == true ? "--skip_ms_validation" : ""
    def string_skip_factor_validation = params.skip_factor_validation == true ? "--skip_factor_validation" : ""
    def string_skip_experimental_design_validation = params.skip_experimental_design_validation == true ? "--skip_experimental_design_validation" : ""
    def string_use_ols_cache_only = params.use_ols_cache_only == true ? "--use_ols_cache_only" : ""
    def string_is_sdrf = is_sdrf == true ? "--is_sdrf" : ""

    """
    quantmsutilsc checksamplesheet --exp_design "${input_file}" ${string_is_sdrf} \\
    ${string_skip_sdrf_validation} \\
    ${string_skip_ms_validation} \\
    ${string_skip_factor_validation} \\
    ${string_skip_experimental_design_validation} \\
    ${string_use_ols_cache_only} 2>&1 | tee input_check.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-utils: \$(pip show quantms-utils | grep "Version" | awk -F ': ' '{print \$2}')
    END_VERSIONS
    """
}
