//
// MODULE: Local to the pipeline
//
include { PERCOLATOR           } from '../../../modules/local/openms/percolator/main'
include { PHOSPHO_SCORING      } from '../phospho_scoring/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { PEPTIDE_DATABASE_SEARCH } from '../peptide_database_search/main'

workflow DDA_ID {
    take:
    ch_file_preparation_results
    ch_database_wdecoy
    ch_ms2_statistics
    ch_expdesign

    main:

    ch_software_versions = channel.empty()

    //
    // SUBWORKFLOW: DatabaseSearchEngines
    //
    PEPTIDE_DATABASE_SEARCH (
        ch_file_preparation_results,
        ch_database_wdecoy,
        ch_expdesign
    )
    ch_software_versions = ch_software_versions.mix(PEPTIDE_DATABASE_SEARCH.out.versions)
    ch_id_files_feats = PEPTIDE_DATABASE_SEARCH.out.ch_id_files_idx

    ch_pmultiqc_consensus = channel.empty()
    ch_pmultiqc_ids = channel.empty()

    //
    // SUBWORKFLOW: Rescoring
    //

    PERCOLATOR(ch_id_files_feats)
    ch_rescoring_results = PERCOLATOR.out.id_files_perc
    ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)

    if (params.enable_mod_localization) {
        PHOSPHO_SCORING(ch_file_preparation_results, ch_rescoring_results)
        ch_software_versions = ch_software_versions.mix(PHOSPHO_SCORING.out.versions.ifEmpty(null))
        ch_id_results = PHOSPHO_SCORING.out.id_onsite
    } else {
        ch_id_results = ch_rescoring_results
    }

    emit:
    ch_pmultiqc_ids         = ch_pmultiqc_ids
    ch_pmultiqc_consensus   = ch_pmultiqc_consensus
    versions                = ch_software_versions
}
