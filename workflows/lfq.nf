/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { PROTEOMICSLFQ } from '../modules/local/openms/proteomicslfq/main'
include { PROTEOMICSLFQ_DETECT } from '../modules/local/openms/proteomicslfq_detect/main'
include { QPX_OPENMSCONSENSUS } from '../modules/bigbio/qpx/openmsconsensus/main'

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
    // MODULE: PROTEOMICSLFQ
    //
    // Settings that shape feature detection. Detecting and combining tasks must agree on them,
    // since ProteomicsLFQ rejects feature checkpoints written with different settings.
    def feature_args = proteomicsLfqFeatureArgs()
    ch_plfq_expdesign = ch_expdesign
    ch_plfq_database = ch_database_wdecoy.first()
    ch_plfq_runs = ch_file_preparation_results.join(ID.out.id_results)

    if (params.lfq_distributed_featurefinding && params.quantification_method == 'feature_intensity') {
        // Scatter: one feature detection task per MS run, each writing a ProteomicsLFQ feature
        // checkpoint. Nextflow caches these tasks individually, so -resume only re-detects runs whose
        // inputs or detection settings changed; FDR, inference and quantification settings only
        // re-run the combining task.
        PROTEOMICSLFQ_DETECT(ch_plfq_runs, ch_plfq_expdesign, ch_plfq_database, feature_args)
        ch_software_versions = ch_software_versions.mix(PROTEOMICSLFQ_DETECT.out.versions.first())

        // Gather: align, link, infer and quantify all runs from their checkpoints.
        PROTEOMICSLFQ([],
                    [],
                    ch_plfq_expdesign,
                    ch_plfq_database,
                    PROTEOMICSLFQ_DETECT.out.checkpoint.map { it -> it[1] }.collect(sort: { a, b -> a.name <=> b.name }),
                    feature_args
                )
    } else {
        if (params.lfq_distributed_featurefinding) {
            log.info "Spectral counting does not detect features: running ProteomicsLFQ as a single task."
        }
        ch_plfq_runs
            .multiMap { it ->
                mzmls: it[1]
                ids: it[2]
            }
            .set{ ch_plfq }
        PROTEOMICSLFQ(ch_plfq.mzmls.collect(),
                    ch_plfq.ids.collect(),
                    ch_plfq_expdesign,
                    ch_plfq_database,
                    [],
                    feature_args
                )
    }
    ch_software_versions = ch_software_versions.mix(PROTEOMICSLFQ.out.versions)

    //
    // MODULE: QPX_OPENMSCONSENSUS  -- convert the OpenMS consensusXML + SDRF into the
    // final clean QPX dataset + MuData (the published quantification artifact).
    //
    QPX_OPENMSCONSENSUS(
        PROTEOMICSLFQ.out.out_consensusXML,
        file(params.input),
        params.accession ?: '',
        // The database the search used. qpx fills null pg.sequence_coverage,
        // pg.molecular_weight and feature.pg_positions from it; decoy entries are
        // skipped, so the with-decoy database is safe to pass. .first() keeps this
        // a value channel, since the same channel already feeds ID and PROTEOMICSLFQ.
        ch_database_wdecoy.first(),
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

//
// ProteomicsLFQ options that shape feature detection (part of the feature checkpoint fingerprint)
//
def proteomicsLfqFeatureArgs() {
    return [
        "-quantification_method ${params.quantification_method}",
        "-targeted_only ${params.targeted_only}",
        "-feature_with_id_min_score ${params.feature_with_id_min_score}",
        params.targeted_only == false ? "-feature_without_id_min_score ${params.feature_without_id_min_score}" : '',
        "-mass_recalibration ${params.mass_recalibration}",
        "-Seeding:algorithm ${params.lfq_seeding_algorithm}",
        "-Seeding:intThreshold ${params.lfq_intensity_threshold}",
        params.quantify_decoys ? '-PeptideQuantification:quantify_decoys' : '',
    ].findAll { arg -> arg }.join(' ')
}

/*
========================================================================================
    THE END
========================================================================================
*/
