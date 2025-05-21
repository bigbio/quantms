process ISOBARIC_ANALYZER {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
    tuple val(meta), path(mzml_file)

    output:
    tuple val(meta), path("${mzml_file.baseName}_iso.consensusXML"),  emit: id_files_consensusXML
    path "versions.yml",   emit: versions
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    if (params.quant_activation_method == "HCD" || params.quant_activation_method == "HCID") diss_meth = "auto"
    else if (params.quant_activation_method == "CID") diss_meth = "Collision-induced dissociation"
    else if (params.quant_activation_method == "ETD") diss_meth = "Electron transfer dissociation"
    else if (params.quant_activation_method == "ECD") diss_meth = "Electron capture dissociation"

    def iso_normalization = params.iso_normalization ? "-quantification:normalization" : ""
    def isotope_correction = params.isotope_correction ? "-quantification:isotope_correction true" : "-quantification:isotope_correction false"

    // Check for isotope correction and load the correction matrix
    if (params.isotope_correction) {
        if (params.plex_corr_matrix_file == null) {
            error("plex_corr_matrix_file is required when isotope_correction is enabled")
        }

        // Read the matrix file and format it into the command-line format
        // Read the matrix file, skipping lines that start with '#' and process the matrix
        def matrix_lines = new File(params.plex_corr_matrix_file).readLines()
        .findAll { !it.startsWith('#') && it.trim() } // Skip lines starting with '#' and empty lines
        .drop(1) // Assuming the first non-comment line is a header
        .collect { line ->
            def values = line.split('/')
            return "\"${values[1]}/${values[2]}/${values[3]}/${values[4]}\""
        }

    // Join the matrix lines into a format for the C++ tool
    def correction_matrix = matrix_lines.join(" ")

    isotope_correction += " -${meta.labelling_type}:correction_matrix ${correction_matrix}"
    }

    """
    IsobaricAnalyzer \\
        -type ${meta.labelling_type} \\
        -in ${mzml_file} \\
        -threads ${task.cpus} \\
        -extraction:select_activation "${diss_meth}" \\
        -extraction:reporter_mass_shift ${params.reporter_mass_shift} \\
        -extraction:min_reporter_intensity ${params.min_reporter_intensity} \\
        -extraction:min_precursor_purity ${params.min_precursor_purity} \\
        -extraction:precursor_isotope_deviation ${params.precursor_isotope_deviation} \\
        ${iso_normalization} \\
        -${meta.labelling_type}:reference_channel ${params.reference_channel} \\
        ${isotope_correction} \\
        -out ${mzml_file.baseName}_iso.consensusXML \\
        ${args} \\
        2>&1 | tee ${mzml_file.baseName}_isob.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IsobaricAnalyzer: \$(IsobaricAnalyzer --version 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
