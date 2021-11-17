
include { saveFiles } from './functions'

params.options = [:]

// Fixing file endings only necessary if the experimental design is user-specified
process PREPROCESS_EXPDESIGN {

    label 'process_very_low'
    label 'process_single_thread'

    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:'expdesign_post', meta:[:], publish_by_meta:[]) }

    input:
    path design

    output:
    path "experimental_design.tsv", emit: ch_expdesign

    script:
    """
    sed 's/.raw\\t/.mzML\\t/I' $design > experimental_design.tsv
    """
}
