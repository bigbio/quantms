/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { PROTEOMICSLFQ } from '../modules/local/openms/proteomicslfq/main'
include { MSSTATS } from '../modules/local/msstats/main'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//
include { ID } from '../subworkflows/local/id'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow LFQ {
    take:
    ch_file_preparation_results
    ch_expdesign
    ch_database_wdecoy

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOWS: ID
    //
    ID(ch_file_preparation_results, ch_database_wdecoy)
    ch_software_versions = ch_software_versions.mix(ID.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: PROTEOMICSLFQ
    //
    ch_file_preparation_results.join(ID.out.id_results)
        .multiMap { it ->
            mzmls: pmultiqc_mzmls: it[1]
            ids: it[2]
        }
        .set{ ch_plfq }
    PROTEOMICSLFQ(ch_plfq.mzmls.collect(),
                ch_plfq.ids.collect(),
                ch_expdesign,
                ch_database_wdecoy
            )
    ch_software_versions = ch_software_versions.mix(PROTEOMICSLFQ.out.version.ifEmpty(null))

    //
    // MODULE: MSSTATS
    //
    ch_msstats_out = Channel.empty()
    if(!params.skip_post_msstats && params.quantification_method == "feature_intensity"){
        MSSTATS(PROTEOMICSLFQ.out.out_msstats)
        ch_msstats_out = MSSTATS.out.msstats_csv
        ch_software_versions = ch_software_versions.mix(MSSTATS.out.version.ifEmpty(null))
    }


    ID.out.psmrescoring_results
        .map { it -> it[1] }
        .set { ch_pmultiqc_ids }

    ID.out.ch_consensus_results
        .map { it -> it[1] }
        .set { ch_pmultiqc_consensus }

    emit:
    ch_pmultiqc_ids         = ch_pmultiqc_ids
    ch_pmultiqc_consensus   = ch_pmultiqc_consensus
    final_result            = PROTEOMICSLFQ.out.out_mztab
    versions                = ch_software_versions
    msstats_in              = PROTEOMICSLFQ.out.out_msstats
    msstats_out             = ch_msstats_out
}

/*
========================================================================================
    THE END
========================================================================================
*/
