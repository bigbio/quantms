//
// MODULE: Local to the pipeline
//
include { DECOYDATABASE } from '../modules/local/openms/decoydatabase/main' addParams( options: modules['decoydatabase'] )
include { CONSENSUSID } from '../modules/local/openms/consensusid/main' addParams( options: modules['consensusid'] )

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
def psm_idfilter = modules['idfilter']
psm_idfilter.args += Utils.joinModuleArgs(["-score:pep \"$params.psm_pep_fdr_cutoff\""])

def idscoreswitcher_to_qval = modules['idscoreswitcher']
def idscoreswitcher_for_luciphor = modules['idscoreswitcher'].clone()

idscoreswitcher_to_qval.args += Utils.joinModuleArgs(["-old_score \"Posterior Error Probability\"", "-new_score_type q-value"])
idscoreswitcher_for_luciphor.args += Utils.joinModuleArgs(["-old_score \"q-value\"", "-new_score_type Posterior Error Probability"])

include { INPUT_CHECK } from '../subworkflows/local/input_check' addParams( options: modules['sdrfparsing'] )
include { CREATE_INPUT_CHANNEL } from '../subworkflows/local/create_input_channel' addParams( sdrfparsing_options: modules['sdrfparsing'] )
include { FILE_PREPARATION } from '../subworkflows/local/file_preparation' addParams(thermorawfileparser: modules['thermorawfileparser'], mzmlindexing: modules['mzmlindexing'], openmspeakpicker: modules['openmspeakpicker'])
include { DATABASESEARCHENGINES } from '../subworkflows/local/databasesearchengines' addParams( msgf_options: modules['searchenginemsgf'], comet_options: modules['searchenginecomet'], indexpeptides_options: modules['indexpeptides'])
include { PSMRESCORING } from '../subworkflows/local/psmrescoring' addParams( extract_psm_feature_options: modules['extractpsmfeature'], percolator_options: modules['percolator'])
include { PSMFDRCONTROL } from '../subworkflows/local/psmfdrcontrol' addParams( idscoreswitcher_to_qval: idscoreswitcher_to_qval, idfilter: psm_idfilter)
include { PHOSPHOSCORING } from '../subworkflows/local/phosphoscoring' addParams ( idscoreswitcher_for_luciphor: idscoreswitcher_for_luciphor)


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
    FILE_PREPARATION.out.results,
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
    PHOSPHOSCORING(FILE_PREPARATION.out.results.join(PSMFDRCONTROL.out.id_filtered))
    ch_software_versions = ch_software_versions.mix(PHOSPHOSCORING.out.version.ifEmpty(null))
    plfq_in_id = PHOSPHOSCORING.out.id_luciphor
} else {
    plfq_in_id = PSMFDRCONTROL.out.id_filtered
}