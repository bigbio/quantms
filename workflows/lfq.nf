/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { PROTEOMICSLFQ } from '../modules/local/openms/proteomicslfq/main'
include { QPX_CONVERT   } from '../modules/local/qpx/qpx_convert/main'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//
include { ID } from '../subworkflows/local/id/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/


workflow LFQ {
    take:
    ch_file_preparation_results
    ch_expdesign
    ch_database_wdecoy

    main:

    ch_software_versions = channel.empty()

    //
    // SUBWORKFLOWS: ID
    //
    ID(ch_file_preparation_results, ch_database_wdecoy, ch_expdesign)
    ch_software_versions = ch_software_versions.mix(ID.out.versions)

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
    ch_software_versions = ch_software_versions.mix(PROTEOMICSLFQ.out.versions)

    //
    // MODULE: QPX_CONVERT  -- refine OpenMS -out_qpx + consensusXML + SDRF into the
    // final clean QPX dataset (replaces the mzTab as the published artifact).
    //
    QPX_CONVERT(
        PROTEOMICSLFQ.out.out_qpx,
        PROTEOMICSLFQ.out.out_consensusXML,
        file(params.input),
    )
    ch_software_versions = ch_software_versions.mix(QPX_CONVERT.out.versions)

    ID.out.psmrescoring_results
        .map { it -> it[1] }
        .set { ch_pmultiqc_ids }

    ID.out.ch_consensus_results
        .map { it -> it[1] }
        .set { ch_pmultiqc_consensus }

    emit:
    ch_pmultiqc_ids         = ch_pmultiqc_ids
    ch_pmultiqc_consensus   = ch_pmultiqc_consensus
    final_result            = QPX_CONVERT.out.out_qpx
    versions                = ch_software_versions
    msstats_in              = PROTEOMICSLFQ.out.out_msstats
}

/*
========================================================================================
    THE END
========================================================================================
*/
