/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { ISOBARIC_WORKFLOW } from '../modules/local/openms/isobaric_workflow/main'
include { MSSTATS_CONVERTER } from '../modules/local/openms/msstats_converter/main'
include { QPX_CONVERT      } from '../modules/local/qpx/qpx_convert/main'

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

    ch_software_versions = channel.empty()

    //
    // SUBWORKFLOWS: ID
    //
    ID(ch_file_preparation_results, ch_database_wdecoy, ch_expdesign)
    ch_software_versions = ch_software_versions.mix(ID.out.versions)

    //
    // SUBWORKFLOW: ISOBARIC_WORKFLOW
    //
    // Extract labelling_type from meta (auto-detected from SDRF)
    ch_file_preparation_results.join(ID.out.id_results)
        .multiMap { it ->
            labelling_type: it[0].labelling_type
            mzmls: it[1]
            ids: it[2]
        }
        .set{ ch_iso_workflow }
    ISOBARIC_WORKFLOW(ch_iso_workflow.labelling_type.first(),
                ch_iso_workflow.mzmls.collect(),
                ch_iso_workflow.ids.collect(),
                ch_expdesign
            )
    ch_software_versions = ch_software_versions.mix(ISOBARIC_WORKFLOW.out.versions)

    //
    // SUBWORKFLOW: MSSTATS_CONVERTER
    //
    MSSTATS_CONVERTER(ISOBARIC_WORKFLOW.out.out_consensusXML, ch_expdesign, "ISO")
    ch_software_versions = ch_software_versions.mix(MSSTATS_CONVERTER.out.versions)

    //
    // MODULE: QPX_CONVERT  -- refine OpenMS -out_qpx + consensusXML + SDRF into the
    // final clean QPX dataset (replaces the mzTab as the published artifact).
    //
    QPX_CONVERT(
        ISOBARIC_WORKFLOW.out.out_qpx,
        ISOBARIC_WORKFLOW.out.out_consensusXML,
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
    msstats_in              = MSSTATS_CONVERTER.out.out_msstats
    versions                = ch_software_versions
}
