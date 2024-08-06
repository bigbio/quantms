process SAMPLESHEET_CHECK {

    tag "$input_file"
    label 'process_single'

    conda "bioconda::sdrf-pipelines=0.0.29"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.29--pyhdfd78af_0' :
        'biocontainers/sdrf-pipelines:0.0.29--pyhdfd78af_0' }"

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
    def skip_sdrf_validation = params.skip_sdrf_validation == true ? "--skip_sdrf_validation" : ""
    def skip_ms_validation = params.skip_ms_validation == true ? "--skip_ms_validation" : ""
    def skip_factor_validation = params.skip_factor_validation == true ? "--skip_factor_validation" : ""
    def skip_experimental_design_validation = params.skip_experimental_design_validation == true ? "--skip_experimental_design_validation" : ""
    def use_ols_cache_only = params.use_ols_cache_only == true ? "--use_ols_cache_only" : ""

    """
    check_samplesheet.py --exp_design "${input_file}" \\
    --is_sdrf ${is_sdrf} \\
    ${skip_sdrf_validation} \\
    ${skip_ms_validation} \\
    ${skip_factor_validation} \\
    ${skip_experimental_design_validation} \\
    ${use_ols_cache_only} 2>&1 | tee input_check.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(parse_sdrf --version 2>&1 | awk -F ' ' '{print \$2}')
    END_VERSIONS
    """
}
