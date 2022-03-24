/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowQuantms.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()


/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

include { TMT } from './tmt'
include { LFQ } from './lfq'
include { DIA } from './dia'
include { PMULTIQC as SUMMARYPIPELINE } from '../modules/local/pmultiqc/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'
include { FILE_PREPARATION as FILE_PREPARATION_LFQ; FILE_PREPARATION as FILE_PREPARATION_TMT; FILE_PREPARATION as FILE_PREPARATION_DIA } from '../subworkflows/local/file_preparation'
include { CREATE_INPUT_CHANNEL } from '../subworkflows/local/create_input_channel'

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'


/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow QUANTMS {

    // TODO check what the standard is here: ch_versions or ch_software_versions
    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // SUBWORKFLOW: Create input channel
    //
    CREATE_INPUT_CHANNEL (
        ch_input,
        INPUT_CHECK.out.is_sdrf
    )
    ch_versions = ch_versions.mix(CREATE_INPUT_CHANNEL.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: File preparation
    //
    FILE_PREPARATION_TMT (
        CREATE_INPUT_CHANNEL.out.ch_meta_config_iso
    )
    FILE_PREPARATION_LFQ (
        CREATE_INPUT_CHANNEL.out.ch_meta_config_lfq
    )

    FILE_PREPARATION_DIA (
        CREATE_INPUT_CHANNEL.out.ch_meta_config_dia
    )

    ch_versions = ch_versions.mix(FILE_PREPARATION_TMT.out.version.ifEmpty(null))
    ch_versions = ch_versions.mix(FILE_PREPARATION_LFQ.out.version.ifEmpty(null))
    ch_versions = ch_versions.mix(FILE_PREPARATION_DIA.out.version.ifEmpty(null))

    FILE_PREPARATION_LFQ.out.results
        .map { it -> it[1] }
        .set { ch_pmultiqc_mzmls_lfq }

    FILE_PREPARATION_TMT.out.results
        .map { it -> it[1] }
        .set { ch_pmultiqc_mzmls_iso }

    FILE_PREPARATION_DIA.out.results
        .map { it -> it[1] }
        .set { ch_pmultiqc_mzmls_dia }

    ch_pmultiqc_mzmls = ch_pmultiqc_mzmls_lfq.mix(ch_pmultiqc_mzmls_iso).mix(ch_pmultiqc_mzmls_dia)

    //
    // WORKFLOW: Run main nf-core/quantms analysis pipeline based on the quantification type
    //
    // TODO if we ever allow mixed labelling types, we need to split the files according to meta.labelling_type which contains
    // labelling_type per file
    ch_pipeline_results = Channel.empty()
    ch_ids_pmultiqc = Channel.empty()

    TMT(FILE_PREPARATION_TMT.out.results, CREATE_INPUT_CHANNEL.out.ch_expdesign)
    ch_ids_pmultiqc = ch_ids_pmultiqc.mix(TMT.out.ch_pmultiqc_ids)
    ch_pipeline_results = ch_pipeline_results.mix(TMT.out.final_result)
    ch_versions = ch_versions.mix(TMT.out.versions.ifEmpty(null))

    LFQ(FILE_PREPARATION_LFQ.out.results, CREATE_INPUT_CHANNEL.out.ch_expdesign)
    ch_ids_pmultiqc = ch_ids_pmultiqc.mix(LFQ.out.ch_pmultiqc_ids)
    ch_pipeline_results = ch_pipeline_results.mix(LFQ.out.final_result)
    ch_versions = ch_versions.mix(LFQ.out.versions.ifEmpty(null))

    DIA(FILE_PREPARATION_DIA.out.results, CREATE_INPUT_CHANNEL.out.ch_expdesign)

    // ch_ids_pmultiqc = ch_ids_pmultiqc.mix(DIA.out.ch_pmultiqc_ids)
    // ch_pipeline_results = ch_pipeline_results.mix(DIA.out.final_result)
    ch_versions = ch_versions.mix(DIA.out.versions.ifEmpty(null))


    //
    // MODULE: Pipeline reporting
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: pmultiqc
    //
    workflow_summary    = WorkflowQuantms.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_quantms_logo = file("$projectDir/assets/nf-core-quantms_logo_light.png")

    SUMMARYPIPELINE (
        CREATE_INPUT_CHANNEL.out.ch_expdesign,
        ch_pmultiqc_mzmls.collect(),
        ch_pipeline_results.combine(ch_multiqc_files.collect()),
        ch_ids_pmultiqc.collect(),
        ch_multiqc_quantms_logo
    )
    multiqc_report      = SUMMARYPIPELINE.out.ch_pmultiqc_report.toList()
    ch_versions         = ch_versions.mix(SUMMARYPIPELINE.out.versions)

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
