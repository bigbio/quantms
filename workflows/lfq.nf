include { ID } from '../subworkflows/local/id')

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow LFQ {

    //
    // SUBWORKFLOW: File preparation
    //
    FILE_PREPARATION (
        CREATE_INPUT_CHANNEL.out.results
    )
    ch_software_versions = ch_software_versions.mix(FILE_PREPARATION.out.version.ifEmpty(null))

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


    //
    // MODULE: Pipeline reporting
    //
    ch_software_versions
        .map { it -> if (it) [ it.baseName, it ] }
        .groupTuple()
        .map { it[1][0] }
        .flatten()
        .collect()
        .set { ch_software_versions }

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_software_versions.map { it }.collect()
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowQuantms.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.yaml.collect())

    SUMMARYPIPELINE (
        ch_multiqc_files.collect()
    )
    multiqc_report       = SUMMARYPIPELINE.out.report.toList()
    ch_software_versions = ch_software_versions.mix(SUMMARYPIPELINE.out.version.ifEmpty(null))
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
