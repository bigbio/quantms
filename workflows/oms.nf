/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//

include { CRYSTALC } from '../modules/local/openms/thirdparty/philosopher/crystalC/main'
include { PEPTIDEPROPHET } from '../modules/local/openms/thirdparty/philosopher/peptideprophet/main'
include { PTMSHEPHERD } from '../modules/local/openms/thirdparty/philosopher/ptmshepherd/main'
include { DELTAMASSHISTOGRAM } from '../modules/local/openms/thirdparty/philosopher/deltamasshistogram/main'

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

    ch_software_versions = ch_software_versions.mix(DATABASESEARCHENGINES.out.versions.ifEmpty(null))

    //
    // Open Search post-processing
    //

    CRYSTALC(ch_file_preparation_results.join(DATABASESEARCHENGINES.out.ch_id_files_pepx).combine(ch_database_wdecoy))
    ch_software_versions = ch_software_versions.mix(CRYSTALC.out.version)

    PEPTIDEPROPHET(CRYSTALC.out.pepxml_file_crystalc.combine(ch_database_wdecoy))
    ch_software_versions = ch_software_versions.mix(PEPTIDEPROPHET.out.version)

    //
    // Modification mapping and histogram creation
    //
    
    PTMSHEPHERD(ch_file_preparation_results.join(PEPTIDEPROPHET.out.psm_philosopher).combine(ch_database_wdecoy))
    ch_software_versions = ch_software_versions.mix(PTMSHEPHERD.out.version)

    DELTAMASSHISTOGRAM(ch_file_preparation_results.join(PTMSHEPHERD.out.ptmshepherd_sum))
    ch_software_versions = ch_software_versions.mix(DELTAMASSHISTOGRAM.out.version)

    ch_modification_sum = DELTAMASSHISTOGRAM.out.delta_mass_histo

    emit:
    final_result    = ch_modification_sum
    versions        = ch_software_versions
}