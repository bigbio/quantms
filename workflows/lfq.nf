/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { PROTEOMICSLFQ } from '../modules/local/openms/proteomicslfq/main'
include { QPX_OPENMSCONSENSUS } from '../modules/bigbio/qpx/openmsconsensus/main'
include { PREPARE_LFQ_GROUPS; group_lfq_inputs } from '../modules/local/prepare_lfq_groups/main'

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
    ch_lfq_runs = ch_file_preparation_results.join(ID.out.id_results)
    if (params.lfq_group_by) {
        def groupColumns = params.lfq_group_by.split(',').collect { it.trim() }
        PREPARE_LFQ_GROUPS(file(params.input), ch_expdesign, file("${projectDir}/bin/split_lfq_groups.py"), groupColumns)
        ch_quant_inputs = group_lfq_inputs(ch_lfq_runs, PREPARE_LFQ_GROUPS.out.manifest)
        ch_software_versions = ch_software_versions.mix(PREPARE_LFQ_GROUPS.out.versions)
    } else {
        ch_quant_inputs = ch_lfq_runs
            .toList()
            .filter { !it.isEmpty() }
            .map { runs -> tuple(runs.collect { it[1] }, runs.collect { it[2] }) }
            .combine(ch_expdesign)
            .map { mzmls, ids, design -> tuple(mzmls, ids, design, file(params.input)) }
    }
    // Reuse the single search database for every quantification group.
    ch_lfq_database = ch_database_wdecoy.first()
    PROTEOMICSLFQ(ch_quant_inputs, ch_lfq_database)
    ch_software_versions = ch_software_versions.mix(PROTEOMICSLFQ.out.versions)

    //
    // MODULE: QPX_OPENMSCONSENSUS  -- convert the OpenMS consensusXML + SDRF into the
    // final clean QPX dataset + MuData (the published quantification artifact).
    //
    QPX_OPENMSCONSENSUS(
        PROTEOMICSLFQ.out.out_consensusXML,
        params.accession ?: '',
        // The database the search used. qpx fills null pg.sequence_coverage,
        // pg.molecular_weight and feature.pg_positions from it; decoy entries are
        // skipped, so the with-decoy database is safe to pass.
        ch_lfq_database,
    )
    ch_software_versions = ch_software_versions.mix(QPX_OPENMSCONSENSUS.out.versions)

    ID.out.psmrescoring_results
        .map { it -> it[1] }
        .set { ch_pmultiqc_ids }

    ID.out.ch_consensus_results
        .map { it -> it[1] }
        .set { ch_pmultiqc_consensus }

    emit:
    ch_pmultiqc_ids         = ch_pmultiqc_ids
    ch_pmultiqc_consensus   = ch_pmultiqc_consensus
    final_result            = QPX_OPENMSCONSENSUS.out.qpx_dataset
    versions                = ch_software_versions
    msstats_in              = PROTEOMICSLFQ.out.out_msstats
}

/*
========================================================================================
    THE END
========================================================================================
*/
