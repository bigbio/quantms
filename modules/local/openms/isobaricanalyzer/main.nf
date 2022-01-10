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

    conda (params.enable_conda ? "bioconda::bumbershoot bioconda::comet-ms bioconda::crux-toolkit=3.2 bioconda::fido=1.0 conda-forge::gnuplot bioconda::luciphor2=2020_04_03 bioconda::msgf_plus=2021.03.22 bioconda::openms=2.7.0 bioconda::pepnovo=20101117 bioconda::percolator=3.5 bioconda::sirius-csifingerid=4.0.1 bioconda::thermorawfileparser=1.3.4 bioconda::xtandem=15.12.15.2 bioconda::openms-thirdparty=2.7.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.7.0--h9ee0642_1"
    } else {
        container "quay.io/biocontainers/openms-thirdparty:2.7.0--h9ee0642_1"
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
