/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { MSSTATS_TMT } from '../modules/local/msstats/msstats_tmt/main'
include { ISOBARIC_WORKFLOW } from '../modules/local/openms/isobaric_workflow/main'
include { MSSTATS_CONVERTER } from '../modules/local/openms/msstats_converter/main'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//
include { ID                } from '../subworkflows/local/id/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow TMT {
    take:
    ch_file_preparation_results
    ch_expdesign
    ch_database_wdecoy

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOWS: ID
    //
    ID(ch_file_preparation_results, ch_database_wdecoy, ch_expdesign)
    ch_software_versions = ch_software_versions.mix(ID.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: ISOBARIC_WORKFLOW
    //
    ch_file_preparation_results.join(ID.out.id_results)
        .multiMap { it ->
            mzmls: pmultiqc_mzmls: it[1]
            ids: it[2]
        }
        .set{ ch_iso_workflow }
    ISOBARIC_WORKFLOW(ch_iso_workflow.mzmls.collect(),
                ch_iso_workflow.ids.collect(),
                ch_expdesign
            )
    ch_software_versions = ch_software_versions.mix(ISOBARIC_WORKFLOW.out.versions.ifEmpty(null))

    //
    // MODULE: MSSTATS_CONVERTER    
    //
    MSSTATS_CONVERTER(ISOBARIC_WORKFLOW.out.out_consensusXML, ch_expdesign, "ISO")
    ch_version = ch_version.mix(MSSTATS_CONVERTER.out.versions.ifEmpty(null))

    //
    // MODULE: MSSTATSTMT
    //
    ch_msstats_out = Channel.empty()
    if(!params.skip_post_msstats){
        MSSTATS_TMT(MSSTATS_CONVERTER.out.out_msstats)
        ch_msstats_out = MSSTATS_TMT.out.msstats_csv
        ch_software_versions = ch_software_versions.mix(MSSTATS_TMT.out.versions.ifEmpty(null))
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
    final_result            = ISOBARIC_WORKFLOW.out.out_mztab
    msstats_in              = MSSTATS_CONVERTER.out.out_msstats
    msstats_out             = ch_msstats_out
    versions                = ch_software_versions
}
