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

workflow ID {
    take:
    file_preparation_results
    ch_database_wdecoy

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOW: DatabaseSearchEngines
    //
    DATABASESEARCHENGINES (
        file_preparation_results,
        ch_database_wdecoy
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
    version                 = ch_software_versions
}
