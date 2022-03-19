process LIBRARYGENERATION {
    label 'process_high'

    if (params.enable_conda) {
        exit 1, "Conda environments cannot be used when using the DIA-NN tool. Please use docker or singularity containers"
    }

    //singularity image ?
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/diann/v1.8.0_cv1/diann_v1.8.0_cv1.img' :
        'biocontainers/diann:v1.8.0_cv1' }"

    input:
    file(fasta)
    file(library_config)

    output:
    path "lib.predicted.speclib", emit: lib_splib
    path "versions.yml", emit: version
    file "*"

    script:
    def args = task.ext.args ?: ''

    """
    diann   `cat library_config.cfg` \\
            --fasta ${fasta} \\
            --fasta-search \\
            --gen-spec-lib \\
            --missed-cleavages $params.allowed_missed_cleavages \\
            --min-pep-len $params.min_peptide_length \\
            --max-pep-len $params.max_peptide_length \\
            --min-pr-charge $params.min_precursor_charge \\
            --max-pr-charge $params.max_precursor_charge \\
            --var-mods $params.max_mods \\
            --threads ${task.cpus} \\
            --smart-profiling \\
            --predictor \\
            --verbose $params.diann_debug \\
            > diann.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        diann: "1.8.0"
    END_VERSIONS
    """
}
