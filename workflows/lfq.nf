/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowQuantms.initialise(params, log)

// Check mandatory parameters and input path to see if they exist
if (params.input) { ch_input = file(params.input, checkIfExists: true) } else { exit 1, 'An SDRF/Experimental design needs to be  provided as input.' }
if (params.database) { ch_db_for_decoy_creation = file(params.database, checkIfExists: true) } else { exit 1, 'No protein database provided' }

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()

//
// MODULE: Local to the pipeline
//
include { DECOYDATABASE } from '../modules/local/openms/decoydatabase/main' addParams( options: modules['decoydatabase'] )
include { CONSENSUSID } from '../modules/local/openms/consensusid/main' addParams( options: modules['consensusid'] )
include { PROTEOMICSLFQ } from '../modules/local/openms/proteomicslfq/main' addParams( options: [:])
include { PMULTIQC } from '../modules/local/pmultiqc/main' addParams( options: modules['pmultiqc'])

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

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

def multiqc_options   = modules['multiqc']
multiqc_options.args += params.multiqc_title ? Utils.joinModuleArgs(["--title \"$params.multiqc_title\""]) : ''
if (!workflow.containerEngine && !params.enable_conda) {
    multiqc_options.args += Utils.joinModuleArgs(["--disable_plugin"])
}

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC as SUMMARYPIPELINE } from '../modules/nf-core/modules/multiqc/main' addParams( options: multiqc_options   )

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow LFQ {

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read and validate input files
    //
    INPUT_CHECK (
        ch_input
    )

    //
    // SUBWORKFLOW: Create input channel
    //
    CREATE_INPUT_CHANNEL (
        ch_input,
        INPUT_CHECK.out.is_sdrf
    )
    ch_software_versions = ch_software_versions.mix(CREATE_INPUT_CHANNEL.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: File preparation
    //
    FILE_PREPARATION (
        CREATE_INPUT_CHANNEL.out.results
    )
    ch_software_versions = ch_software_versions.mix(FILE_PREPARATION.out.version.ifEmpty(null))

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
