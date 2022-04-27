process LUCIPHORADAPTER {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::openms-thirdparty=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(mzml_file), path(id_file)


    output:
    tuple val(meta), path("${id_file.baseName}_luciphor.idXML"), emit: ptm_in_id_luciphor
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    // The OpenMS adapters need the actuall jar file, not the executable/shell wrapper that (bio)conda creates
    luciphor_jar = ''
    if (workflow.containerEngine || (task.executor == "awsbatch")) {
        luciphor_jar = "-executable \$(find /usr/local/share/luciphor2-*/luciphor2.jar -maxdepth 0)"
    } else if (params.enable_conda) {
        luciphor_jar = "-executable \$(find \$CONDA_PREFIX/share/luciphor2-*/luciphor2.jar -maxdepth 0)"
    }

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def losses = params.luciphor_neutral_losses ? "-neutral_losses ${params.luciphor_neutral_losses}" : ""
    def dec_mass = params.luciphor_decoy_mass ? "-decoy_mass ${params.luciphor_decoy_mass}" : ""
    def dec_losses = params.luciphor_decoy_neutral_losses ? "-decoy_neutral_losses ${params.luciphor_decoy_neutral_losses}" : ""

    """
    LuciphorAdapter \\
        -id ${id_file} \\
        -in ${mzml_file} \\
        ${luciphor_jar} \\
        -out ${id_file.baseName}_luciphor.idXML \\
        -threads $task.cpus \\
        -num_threads $task.cpus \\
        -target_modifications ${params.mod_localization.tokenize(',').collect { "'${it}'" }.join(" ") } \\
        -fragment_method $meta.dissociationmethod \\
        ${losses} \\
        ${dec_mass} \\
        ${dec_losses} \\
        -max_charge_state $params.max_precursor_charge \\
        -max_peptide_length $params.max_peptide_length \\
        $args \\
        |& tee ${id_file.baseName}_luciphor.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        LuciphorAdapter: \$(LuciphorAdapter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
        Luciphor: \$(luciphor2 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
