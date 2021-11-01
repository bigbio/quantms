// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process ISOBARICANALYZER {
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        pattern: "*.log",
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms:2.6.0--h4afb90d_0"
    } else {
        container "quay.io/biocontainers/openms:2.6.0--h4afb90d_0"
    }

    input:
    tuple val(mzml_id), path (mzml_file)

    output:
    tuple mzml_id, path "${mzml_file.baseName}_iso.consensusXML",  emit: id_files_consensusXML
    path "*.version.txt",   emit: version
    path "*.log",   emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    IsobaricAnalyzer \\
        -type $options.label \\
        -in ${mzml_file} \\
        -threads $task.cpus \\
        -extraction:select_activation $options.diss_meth \\
        -extraction:reporter_mass_shift $options.reporter_mass_shift \\
        -extraction:min_reporter_intensity $options.min_reporter_intensity \\
        -extraction:min_precursor_purity $options.min_precursor_purity \\
        -extraction:precursor_isotope_deviation $options.precursor_isotope_deviation \\
        ${options.iso_normalization} \\
        -${options.label}:reference_channel $options.reference_channel \\
        -debug $options.iso_debug \\
        -out ${mzml_file.baseName}_iso.consensusXML \\
        > ${mzml_file.baseName}_isob.log

    echo \$(IsobaricAnalyzer --version 2>&1) > ${software}.version.txt
    """
}
