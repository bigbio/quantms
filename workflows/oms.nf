/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//

include { PEPTIDEPROPHET } from '../modules/local/openms/thirdparty/philosopher/peptideprophet/main'
include { PTMSHEPHERD } from '../modules/local/openms/thirdparty/philosopher/ptmshepherd/main'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//

include { DATABASESEARCHENGINES } from '../subworkflows/local/databasesearchengines'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow OMS {
    take:
    ch_file_preparation_results
    ch_database_wdecoy

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOW: DatabaseSearchEngines
    //
    DATABASESEARCHENGINES(
        ch_file_preparation_results,
        ch_database_wdecoy
    )

    ch_pepxml_files = DATABASESEARCHENGINES.out.ch_id_files_pepx
    ch_software_versions = ch_software_versions.mix(DATABASESEARCHENGINES.out.versions.ifEmpty(null))

    //
    // Open Search post-processing
    //

    PEPTIDEPROPHET(ch_pepxml_files.combine(ch_database_wdecoy))

    ch_psm_files = PEPTIDEPROPHET.out.psm_philosopher
    ch_software_versions = ch_software_versions.mix(PEPTIDEPROPHET.out.version)

    //
    // Modification mapping
    //
    
    PTMSHEPHERD(ch_file_preparation_results.join(ch_psm_files).mix(ch_database_wdecoy))

    ch_modification_sum = PTMSHEPHERD.out.ptmshepherd_sum
    ch_software_versions = ch_software_versions.mix(PTMSHEPHERD.out.version)

    emit:
    final_result    = ch_modification_sum
    versions        = ch_software_versions
}