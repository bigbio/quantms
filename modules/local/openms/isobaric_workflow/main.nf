process ISOBARIC_WORKFLOW {
    tag "${expdes.baseName}"
    label 'process_high'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
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

    """
    IsobaricWorkflow \\
        -threads ${task.cpus} \\
        -in ${mzml_sorted.join(' ')} \\
        -in_id ${id_sorted.join(' ')} \\
        -exp_design ${expdes} \\
        -type ${params.type} \\
        -inference_method ${params.protein_inference_method} \\
        -protein_quantification ${params.protein_quant} \\
        -psmFDR ${params.psm_level_fdr_cutoff} \\
        -proteinFDR ${params.protein_level_fdr_cutoff} \\
        -picked_fdr ${params.picked_fdr} \\
        -picked_decoy_string ${params.decoy_string} \\
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
