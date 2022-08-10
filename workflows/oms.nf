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
    DATABASESEARCHENGINES (
        ch_file_preparation_results,
        ch_database_wdecoy
    )
    ch_software_versions = ch_software_versions.mix(DATABASESEARCHENGINES.out.versions.ifEmpty(null))

    //
    // Open Search post-processing
    //

    /*(DATABASESEARCHENGINES.out.ch_id_files_pepx).mix(ch_database_wdecoy)
        .multiMap { it ->
            ids: it[1]
            db: it[2]
        }
        .set{ ch_philosopher_pep }
    */
    PEPTIDEPROPHET (
        DATABASESEARCHENGINES.out.ch_id_files_pepx.combine(ch_database_wdecoy)
    )
    
    ch_software_versions = ch_software_versions.mix(PEPTIDEPROPHET.out.version)

    ch_file_preparation_results.join(PEPTIDEPROPHET.out.psm_philosopher).mix(ch_database_wdecoy)
        .multiMap { it ->
            mzmls: pmultiqc_mzmls: it[1]
            psms: it[2]
            db: it[3]
        }
        .set{ ch_philosopher_psm }
    
    PTMSHEPHERD(ch_philosopher_psm.mzmls,
            ch_philosopher_psm.psms,
            ch_philosopher_psm.db)

    ch_software_versions = ch_software_versions.mix(PTMSHEPHERD.out.version)

    emit:
    final_result    = PTMSHEPHERD.out.ptmshepherd_sum
    versions        = ch_software_versions
}