process LUCIPHORADAPTER {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::bumbershoot bioconda::comet-ms bioconda::crux-toolkit=3.2 bioconda::fido=1.0 conda-forge::gnuplot bioconda::luciphor2=2020_04_03 bioconda::msgf_plus=2021.03.22 bioconda::openms=2.8.0 bioconda::pepnovo=20101117 bioconda::percolator=3.5 bioconda::sirius-csifingerid=4.0.1 bioconda::thermorawfileparser=1.3.4 bioconda::xtandem=15.12.15.2 bioconda::openms-thirdparty=2.8.0" : null)
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
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def losses = params.luciphor_neutral_losses ? '-neutral_losses "${params.luciphor_neutral_losses}"' : ''
    def dec_mass = params.luciphor_decoy_mass ? '-decoy_mass "${params.luciphor_decoy_mass}"' : ''
    def dec_losses = params.luciphor_decoy_neutral_losses ? '-decoy_neutral_losses "${params.luciphor_decoy_neutral_losses}' : ''

    """
    LuciphorAdapter \\
        -id ${id_file} \\
        -in ${mzml_file} \\
        -out ${id_file.baseName}_luciphor.idXML \\
        -threads $task.cpus \\
        -num_threads $task.cpus \\
        -target_modifications $params.mod_localization \\
        -fragment_method $meta.dissociationmethod \\
        ${losses} \\
        ${dec_mass} \\
        ${dec_losses} \\
        -max_charge_state $params.max_precursor_charge \\
        -max_peptide_length $params.max_peptide_length \\
        $args \\
        > ${id_file.baseName}_luciphor.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        LuciphorAdapter: \$(LuciphorAdapter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
