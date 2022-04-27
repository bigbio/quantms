process ISOBARICANALYZER {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:2.8.0--h7ca0330_1' :
        'quay.io/biocontainers/openms:2.8.0--h7ca0330_1' }"

    input:
    tuple val(meta), path(mzml_file)

    output:
    tuple val(meta), path("${mzml_file.baseName}_iso.consensusXML"),  emit: id_files_consensusXML
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (meta.dissociationmethod == "HCD" || meta.dissociationmethod == "HCID") diss_meth = "auto"
    else if (meta.dissociationmethod == "CID") diss_meth = "Collision-induced dissociation"
    else if (meta.dissociationmethod == "ETD") diss_meth = "Electron transfer dissociation"
    else if (meta.dissociationmethod == "ECD") diss_meth = "Electron capture dissociation"

    iso_normalization = params.iso_normalization ? "-quantification:normalization" : ""

    """
    IsobaricAnalyzer \\
        -type $meta.labelling_type \\
        -in ${mzml_file} \\
        -threads $task.cpus \\
        -extraction:select_activation "${diss_meth}" \\
        -extraction:reporter_mass_shift $params.reporter_mass_shift \\
        -extraction:min_reporter_intensity $params.min_reporter_intensity \\
        -extraction:min_precursor_purity $params.min_precursor_purity \\
        -extraction:precursor_isotope_deviation $params.precursor_isotope_deviation \\
        ${iso_normalization} \\
        -${meta.labelling_type}:reference_channel $params.reference_channel \\
        -out ${mzml_file.baseName}_iso.consensusXML \\
        $args \\
        |& tee ${mzml_file.baseName}_isob.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IsobaricAnalyzer: \$(IsobaricAnalyzer --version 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
