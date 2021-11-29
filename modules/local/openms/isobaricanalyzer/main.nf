// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process ISOBARICANALYZER {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        pattern: "*.log",
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://ftp.pride.ebi.ac.uk/pride/data/tools/quantms-dev.sif"
    } else {
        container "quay.io/bigbio/quantms:dev"
    }

    input:
    tuple val(meta), path(mzml_file)

    output:
    tuple val(meta), path("${mzml_file.baseName}_iso.consensusXML"),  emit: id_files_consensusXML
    path "*.version.txt",   emit: version
    path "*.log",   emit: log

    script:
    def software = getSoftwareName(task.process)

    if (meta.dissociationmethod == "HCD") diss_meth = "High-energy collision-induced dissociation"
    else if (meta.dissociationmethod == "CID") diss_meth = "Collision-induced dissociation"
    else if (meta.dissociationmethod == "ETD") diss_meth = "Electron transfer dissociation"
    else if (meta.dissociationmethod == "ECD") diss_meth = "Electron capture dissociation"

    iso_normalization = params.iso_normalization ? "-quantification:normalization" : ""

    """
    IsobaricAnalyzer \\
        -type $meta.label \\
        -in ${mzml_file} \\
        -threads $task.cpus \\
        -extraction:select_activation "${diss_meth}" \\
        -extraction:reporter_mass_shift $params.reporter_mass_shift \\
        -extraction:min_reporter_intensity $params.min_reporter_intensity \\
        -extraction:min_precursor_purity $params.min_precursor_purity \\
        -extraction:precursor_isotope_deviation $params.precursor_isotope_deviation \\
        ${iso_normalization} \\
        -${meta.label}:reference_channel $params.reference_channel \\
        -debug $params.iso_debug \\
        -out ${mzml_file.baseName}_iso.consensusXML \\
        > ${mzml_file.baseName}_isob.log

    echo \$(IsobaricAnalyzer --version 2>&1) > ${software}.version.txt
    """
}
