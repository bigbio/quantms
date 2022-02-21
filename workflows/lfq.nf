/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { PROTEOMICSLFQ } from '../modules/local/openms/proteomicslfq/main'
include { PMULTIQC } from '../modules/local/pmultiqc/main'

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
    file_preparation_results
    ch_expdesign

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOWS: ID
    //
    ID(file_preparation_results)
    ch_software_versions = ch_software_versions.mix(ID.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: PROTEOMICSLFQ
    //
    file_preparation_results.join(ID.out.id_results)
        .multiMap { it ->
            mzmls: pmultiqc_mzmls: it[1]
            ids: it[2]
        }
        .set{ ch_plfq }
    PROTEOMICSLFQ(ch_plfq.mzmls.collect(),
                ch_plfq.ids.collect(),
                ch_expdesign,
                ID.out.searchengine_in_db
            )
    ch_software_versions = ch_software_versions.mix(PROTEOMICSLFQ.out.version.ifEmpty(null))

    //
    // MODULE: PMULTIQC
    // TODO PMULTIQC package will be improved and restructed
    if (params.enable_pmultiqc) {
        ID.out.psmrescoring_results.map { it -> it[1] }.set { ch_ids_pmultiqc }
        PMULTIQC(ch_expdesign, ch_plfq.pmultiqc_mzmls.collect(),
            PROTEOMICSLFQ.out.out_mztab.combine(PROTEOMICSLFQ.out.out_consensusXML).combine(PROTEOMICSLFQ.out.out_msstats),
            ch_ids_pmultiqc.collect()
        )
    }
}

/*
========================================================================================
    THE END
========================================================================================
*/
