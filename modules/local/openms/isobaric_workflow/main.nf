process ISOBARIC_WORKFLOW {
    tag "${expdes.baseName}"
    label 'process_high'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
    val(labelling_type)
    path(mzmls)
    path(id_files)
    path(expdes)

    output:
    path "${expdes.baseName}_openms.mzTab", emit: out_mztab
    path "${expdes.baseName}_openms.consensusXML", emit: out_consensusXML
    path "*.log", emit: log
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def extractBaseName = { filename ->
        def name = filename.toString()
        name = name.replaceAll(/\.mzML$/, '')

        if (name.endsWith('.idXML')) {
            name = name.replaceAll(/\.idXML$/, '')
            name = name.replaceAll(/_(comet|msgf|sage|consensus)(_perc)?(_filter)?(_fdr)?$/, '')
        }
        return name
    }

    def mzml_sorted = mzmls.collect().sort{ a, b ->
        extractBaseName(a.name) <=> extractBaseName(b.name)
    }
    def id_sorted = id_files.collect().sort{ a, b ->
        extractBaseName(a.name) <=> extractBaseName(b.name)
    }

    // Build isotope correction matrix argument if enabled
    def isotope_correction = ""
    if (params.isotope_correction && params.plex_corr_matrix_file != null) {
        def matrix_lines = new File(params.plex_corr_matrix_file).readLines()
            .findAll { !it.startsWith('#') && it.trim() }
            .drop(1)
            .collect { line ->
                def values = line.split('/')
                if (labelling_type == 'tmt18plex' || labelling_type == 'tmt16plex') {
                    return "\"${values[1]}/${values[2]}/${values[3]}/${values[4]}/${values[5]}/${values[6]}/${values[7]}/${values[8]}\""
                } else {
                    return "\"${values[1]}/${values[2]}/${values[3]}/${values[4]}\""
                }
            }
        def correction_matrix = matrix_lines.join(" ")
        isotope_correction = "-quantification:isotope_correction true -${labelling_type}:correction_matrix ${correction_matrix}"
    }

    """
    IsobaricWorkflow \\
        -threads ${task.cpus} \\
        -in ${mzml_sorted.join(' ')} \\
        -in_id ${id_sorted.join(' ')} \\
        -exp_design ${expdes} \\
        -type ${labelling_type} \\
        -inference_method ${params.protein_inference_method} \\
        -protein_quantification ${params.protein_quant} \\
        -psmFDR ${params.psm_level_fdr_cutoff} \\
        -proteinFDR ${params.protein_level_fdr_cutoff} \\
        -picked_fdr ${params.picked_fdr} \\
        -picked_decoy_string ${params.decoy_string} \\
        -extraction:min_precursor_purity ${params.min_precursor_purity} \\
        -extraction:precursor_isotope_deviation ${params.precursor_isotope_deviation} \\
        -extraction:min_reporter_intensity ${params.min_reporter_intensity} \\
        ${isotope_correction} \\
        -out ${expdes.baseName}_openms.consensusXML \\
        -out_mzTab ${expdes.baseName}_openms.mzTab \\
        $args \\
        2>&1 | tee isobaricworkflow.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        IsobaricWorkflow: \$(IsobaricWorkflow 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
