//
// Summary pipeline using PMULTIQC
//

include { PMULTIQC } from '../../../modules/local/pmultiqc/main'

workflow SUMMARY_PIPELINE {
    take:
    ch_exp_design
    ch_pipeline_results
    ch_multiqc_files
    ch_ids_pmultiqc
    ch_consensus_pmultiqc
    ch_msstats_in
    ch_multiqc_quantms_logo

    main:
    PMULTIQC(
        ch_exp_design
            .combine(ch_pipeline_results.ifEmpty([]).combine(ch_multiqc_files.collect())
            .combine(ch_ids_pmultiqc.collect().ifEmpty([]))
            .combine(ch_consensus_pmultiqc.collect().ifEmpty([])))
            .combine(ch_msstats_in.ifEmpty([])),
        ch_multiqc_quantms_logo
    )

    emit:
    ch_pmultiqc_report = PMULTIQC.out.ch_pmultiqc_report.toList()
    versions = PMULTIQC.out.versions
}