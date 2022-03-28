//
// MODULE: Local to the pipeline
//
include { DECOYDATABASE } from '../../modules/local/openms/decoydatabase/main'
include { CONSENSUSID } from '../../modules/local/openms/consensusid/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { DATABASESEARCHENGINES } from './databasesearchengines'
include { PSMRESCORING } from './psmrescoring'
include { PSMFDRCONTROL } from './psmfdrcontrol'
include { PHOSPHOSCORING } from './phosphoscoring'

if (params.database) { ch_db_for_decoy_creation = file(params.database, checkIfExists: true) } else { exit 1, 'No protein database provided' }

workflow ID {
    take:
    file_preparation_results

    main:

    ch_software_versions = Channel.empty()
    //
    // MODULE: Generate decoy database
    //
    (searchengine_in_db, pepidx_in_db, plfq_in_db) = ( params.add_decoys
        ? [ Channel.empty(), Channel.empty(), Channel.empty(), Channel.empty() ]
        : [ Channel.fromPath(params.database), Channel.fromPath(params.database), Channel.fromPath(params.database) ] )
    if (params.add_decoys) {
        DECOYDATABASE(
            ch_db_for_decoy_creation
        )
        searchengine_in_db = DECOYDATABASE.out.db_decoy
        ch_software_versions = ch_software_versions.mix(DECOYDATABASE.out.version.ifEmpty(null))
    }

    //
    // SUBWORKFLOW: DatabaseSearchEngines
    //
    DATABASESEARCHENGINES (
        file_preparation_results,
        searchengine_in_db
    )
    ch_software_versions = ch_software_versions.mix(DATABASESEARCHENGINES.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: PSMReScoring
    //
    PSMRESCORING (DATABASESEARCHENGINES.out.ch_id_files_idx)
    ch_software_versions = ch_software_versions.mix(PSMRESCORING.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: PSMFDRCONTROL
    //
    ch_psmfdrcontrol = Channel.empty()
    if (params.search_engines.split(",").size() > 1) {
        CONSENSUSID(PSMRESCORING.out.results.groupTuple(size: params.search_engines.split(",").size()))
        ch_software_versions = ch_software_versions.mix(CONSENSUSID.out.version.ifEmpty(null))
        ch_psmfdrcontrol = CONSENSUSID.out.consensusids
    } else {
        ch_psmfdrcontrol = PSMRESCORING.out.results
    }

    PSMFDRCONTROL(ch_psmfdrcontrol)
    ch_software_versions = ch_software_versions.mix(PSMFDRCONTROL.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW：PHOSPHOSCORING
    //
    if (params.enable_mod_localization) {
        PHOSPHOSCORING(file_preparation_results, PSMFDRCONTROL.out.id_filtered)
        ch_software_versions = ch_software_versions.mix(PHOSPHOSCORING.out.version.ifEmpty(null))
        id_results = PHOSPHOSCORING.out.id_luciphor
    } else {
        id_results = PSMFDRCONTROL.out.id_filtered
    }

    emit:
    id_results              = id_results
    psmrescoring_results    = PSMRESCORING.out.results
    searchengine_in_db      = searchengine_in_db
    version                 = ch_software_versions
}
