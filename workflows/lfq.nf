/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow LFQ {

    //
    // SUBWORKFLOW: PROTEOMICSLFQ
    //
    FILE_PREPARATION.out.results.join(plfq_in_id)
        .multiMap { it ->
            mzmls: pmultiqc_mzmls: it[1]
            ids: it[2]
        }
        .set{ ch_plfq }
    PROTEOMICSLFQ(ch_plfq.mzmls.collect(),
                ch_plfq.ids.collect(),
                CREATE_INPUT_CHANNEL.out.ch_expdesign,
                searchengine_in_db
            )
    ch_software_versions = ch_software_versions.mix(PROTEOMICSLFQ.out.version.ifEmpty(null))

    //
    // MODULE: PMULTIQC
    // TODO PMULTIQC package will be improved and restructed
    if (params.enable_pmultiqc) {
        PSMRESCORING.out.results.map { it -> it[1] }.set { ch_ids_pmultiqc }
        PMULTIQC(CREATE_INPUT_CHANNEL.out.ch_expdesign, ch_plfq.pmultiqc_mzmls.collect(),
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
