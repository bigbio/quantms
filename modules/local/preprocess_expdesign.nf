
include { initOptions; saveFiles } from './functions'

params.options = [:]
options = initOptions(params.options)

// Fixing file endings only necessary if the experimental design is user-specified
    process PREPROCESS_EXPDESIGN {

    label 'process_very_low'
    label 'process_single_thread'

    input:
    path design

    output:
    path "experimental_design.tsv", emit: ch_expdesign

    script:
    """
    sed 's/.raw\\t/.mzML\\t/I' $design > experimental_design.tsv
    """
}
