//
// MODULE: Local to the pipeline
//
include { CONSENSUSID   } from '../../../modules/local/openms/consensusid/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { PEPTIDE_DATABASE_SEARCH } from '../peptide_database_search/main'
include { PSM_RESCORING          } from '../psm_rescoring/main'
include { PSM_FDR_CONTROL         } from '../psm_fdr_control/main'
include { PHOSPHO_SCORING_WORKFLOW as PHOSPHO_SCORING } from '../phospho_scoring/main'

workflow ID {
    take:
    ch_file_preparation_results
    ch_database_wdecoy
    ch_expdesign

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOW: DatabaseSearchEngines
    //
    PEPTIDE_DATABASE_SEARCH (
        ch_file_preparation_results,
        ch_database_wdecoy
    )
    ch_software_versions = ch_software_versions.mix(PEPTIDE_DATABASE_SEARCH.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: PSMReScoring
    //
    PSM_RESCORING (ch_file_preparation_results, PEPTIDE_DATABASE_SEARCH.out.ch_id_files_idx, ch_expdesign)
    ch_software_versions = ch_software_versions.mix(PSM_RESCORING.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: PSMFDRCONTROL
    //
    ch_psmfdrcontrol     = Channel.empty()
    ch_consensus_results = Channel.empty()
    // split returns String[], whereas tokenize returns a list, unique works on lists
    def n_unique_search_engines = params.search_engines.tokenize(",").unique().size()
    if (n_unique_search_engines > 1) {
        // 'remainder: true' will keep remainders which do not match the specified size
        // if the 'size' is not matched, an empty channel will be returned and
        // nothing will be run for the 'CONSENSUSID' process
        CONSENSUSID(PSM_RESCORING.out.results.groupTuple(size: n_unique_search_engines))
        ch_software_versions = ch_software_versions.mix(CONSENSUSID.out.versions.ifEmpty(null))
        ch_psmfdrcontrol = CONSENSUSID.out.consensusids
        ch_consensus_results = CONSENSUSID.out.consensusids
    } else {
        ch_psmfdrcontrol = PSM_RESCORING.out.results
    }

    PSMFDRCONTROL(ch_psmfdrcontrol)
    ch_software_versions = ch_software_versions.mix(PSM_FDR_CONTROL.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW：PHOSPHOSCORING
    //
    if (params.enable_mod_localization) {
        PHOSPHO_SCORING(ch_file_preparation_results, PSM_FDR_CONTROL.out.id_filtered)
        ch_software_versions = ch_software_versions.mix(PHOSPHO_SCORING.out.versions.ifEmpty(null))
        ch_id_results = PHOSPHO_SCORING.out.id_luciphor
    } else {
        ch_id_results = PSM_FDR_CONTROL.out.id_filtered
    }

    emit:
    id_results              = ch_id_results
    psmrescoring_results    = PSM_RESCORING.out.results
    ch_consensus_results    = ch_consensus_results
    versions                 = ch_software_versions
}
