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
include { GET_SOFTWARE_VERSIONS } from '../modules/local/get_software_versions' addParams( options: [publish_files : ['tsv':'']] )
include { DECOYDATABASE } from '../modules/local/openms/decoydatabase/main' addParams( options: modules['decoydatabase'] )

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check' addParams( options: [:] )
include { CREATE_INPUT_CHANNEL } from '../subworkflows/local/create_input_channel' addParams( sdrfparsing_options: modules['sdrfparsing'] )
include { FILE_PREPARATION } from '../subworkflows/local/file_preparation' addParams(options: [:])
include { DATABASESEARCHENGINES } from '../subworkflows/local/databasesearchengines' addParams( options: [:])

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

def multiqc_options   = modules['multiqc']
multiqc_options.args += params.multiqc_title ? Utils.joinModuleArgs(["--title \"$params.multiqc_title\""]) : ''

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC } from '../modules/nf-core/modules/multiqc/main' addParams( options: multiqc_options   )

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow TMT {

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
        INPUT_CHECK.out.ch_input_file,
        INPUT_CHECK.out.is_sdrf
    )
    ch_software_versions = ch_software_versions.mix(CREATE_INPUT_CHANNEL.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: File preparation
    //
    FILE_PREPARATION (
        CREATE_INPUT_CHANNEL.out.spectra_files
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

        ch_software_versions = ch_software_versions.mix(DECOYDATABASE.out.version.ifEmpty(null))
    }

    //
    // SUBWORKFLOW: DatabaseSearchEngines
    //
    DATABASESEARCHENGINES (
        FILE_PREPARATION.out.results,
        searchengine_in_db.mix(DECOYDATABASE.out.db_decoy),
        CREATE_INPUT_CHANNEL.out.comet_settings,
        CREATE_INPUT_CHANNEL.out.idx_settings
    )
    ch_software_versions = ch_software_versions.mix(DATABASESEARCHENGINES.out.versions.ifEmpty(null))

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

    GET_SOFTWARE_VERSIONS (
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
    ch_multiqc_files = ch_multiqc_files.mix(GET_SOFTWARE_VERSIONS.out.yaml.collect())

    MULTIQC (
        ch_multiqc_files.collect()
    )
    multiqc_report       = MULTIQC.out.report.toList()
    ch_software_versions = ch_software_versions.mix(MULTIQC.out.version.ifEmpty(null))
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
