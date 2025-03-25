//
// MODULE: Local to the pipeline
//
include { CONSENSUSID   } from '../../modules/local/openms/consensusid/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { DATABASESEARCHENGINES } from './databasesearchengines'
include { PSMRESCORING          } from './psmrescoring'
include { PSMFDRCONTROL         } from './psmfdrcontrol'
include { PHOSPHOSCORING        } from './phosphoscoring'

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
    DATABASESEARCHENGINES (
        ch_file_preparation_results,
        ch_database_wdecoy
    )
    ch_software_versions = ch_software_versions.mix(DATABASESEARCHENGINES.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: PSMReScoring
    //
    PSMRESCORING (ch_file_preparation_results, DATABASESEARCHENGINES.out.ch_id_files_idx, ch_expdesign)
    ch_software_versions = ch_software_versions.mix(PSMRESCORING.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: PSMFDRCONTROL
    //
    ch_psmfdrcontrol     = Channel.empty()
    ch_consensus_results = Channel.empty()
    // split returns String[], whereas tokenize returns a list, unique works on lists
    n_unique_search_engines = params.search_engines.tokenize(",").unique().size()
    if (n_unique_search_engines > 1) {
        // 'remainder: true' will keep remainders which do not match the specified size
        // if the 'size' is not matched, an empty channel will be returned and 
        // nothing will be run for the 'CONSENSUSID' process
        CONSENSUSID(PSMRESCORING.out.results.groupTuple(size: n_unique_search_engines))
        ch_software_versions = ch_software_versions.mix(CONSENSUSID.out.versions.ifEmpty(null))
        ch_psmfdrcontrol = CONSENSUSID.out.consensusids
        ch_consensus_results = CONSENSUSID.out.consensusids
    } else {
        ch_psmfdrcontrol = PSMRESCORING.out.results
    }

    PSMFDRCONTROL(ch_psmfdrcontrol)
    ch_software_versions = ch_software_versions.mix(PSMFDRCONTROL.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW：PHOSPHOSCORING
    //
    if (params.enable_mod_localization) {
        PHOSPHOSCORING(ch_file_preparation_results, PSMFDRCONTROL.out.id_filtered)
        ch_software_versions = ch_software_versions.mix(PHOSPHOSCORING.out.versions.ifEmpty(null))
        ch_id_results = PHOSPHOSCORING.out.id_luciphor
    } else {
        ch_id_results = PSMFDRCONTROL.out.id_filtered
    }

    emit:
    id_results              = ch_id_results
    psmrescoring_results    = PSMRESCORING.out.results
    ch_consensus_results    = ch_consensus_results
    versions                 = ch_software_versions
}
