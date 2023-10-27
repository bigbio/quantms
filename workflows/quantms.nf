/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowQuantms.initialise(params, log)

// Check conflicting parameters
if (params.decoy_string_position == "suffix" && params.searchengines.contains("sage"))
{
    log.error "Sage does not support decoy suffixes. Please change your input database or generate with add_decoys and decoy_string_position 'prefix' (default)."
}

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

ch_multiqc_config          = file("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)


/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

include { TMT } from './tmt'
include { LFQ } from './lfq'
include { DIA } from './dia'
include { PMULTIQC as SUMMARYPIPELINE } from '../modules/local/pmultiqc/main'
include { DECOYDATABASE } from '../modules/local/openms/decoydatabase/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'
include { FILE_PREPARATION } from '../subworkflows/local/file_preparation'
include { CREATE_INPUT_CHANNEL } from '../subworkflows/local/create_input_channel'

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//

include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'



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
        file(params.input)
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
    // TODO: OPTIONAL, you can use nf-validation plugin to create an input channel from the samplesheet with Channel.fromSamplesheet("input")
    // See the documentation https://nextflow-io.github.io/nf-validation/samplesheets/fromSamplesheet/
    // ! There is currently no tooling to help you write a sample sheet schema

    //
    // SUBWORKFLOW: Create input channel
    //
    CREATE_INPUT_CHANNEL (
        INPUT_CHECK.out.ch_input_file,
        INPUT_CHECK.out.is_sdrf
    )
    ch_versions = ch_versions.mix(CREATE_INPUT_CHANNEL.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: File preparation
    //
    FILE_PREPARATION (
        CREATE_INPUT_CHANNEL.out.ch_meta_config_iso.mix(CREATE_INPUT_CHANNEL.out.ch_meta_config_lfq).mix(CREATE_INPUT_CHANNEL.out.ch_meta_config_dia)
    )

    ch_versions = ch_versions.mix(FILE_PREPARATION.out.version.ifEmpty(null))

    FILE_PREPARATION.out.results
            .branch {
                dia: it[0].acquisition_method.contains("dia")
                iso: it[0].labelling_type.contains("tmt") || it[0].labelling_type.contains("itraq")
                lfq: it[0].labelling_type.contains("label free")
            }
            .set{ch_fileprep_result}


    //
    // WORKFLOW: Run main nf-core/quantms analysis pipeline based on the quantification type
    //
    ch_pipeline_results = Channel.empty()
    ch_ids_pmultiqc = Channel.empty()
    ch_msstats_in = Channel.empty()
    ch_consensus_pmultiqc = Channel.empty()

    //
    // MODULE: Generate decoy database
    //
    if (params.database) { ch_db_for_decoy_creation = Channel.from(file(params.database, checkIfExists: true)) } else { exit 1, 'No protein database provided' }


    CREATE_INPUT_CHANNEL.out.ch_meta_config_iso.mix(CREATE_INPUT_CHANNEL.out.ch_meta_config_lfq).first()         // Only run if iso or lfq have at least one file
    | combine( ch_db_for_decoy_creation )    // Combine it so now the channel has elements like [potential_trigger_channel_element, actual_db], [potential_trigger_channel_element, actual_db2], etc (there should only be one DB though)
    | map { it[-1] }         // Remove the "trigger" part
    | set {ch_db_for_decoy_creation_or_null}

    ch_searchengine_in_db = params.add_decoys ? Channel.empty() : Channel.fromPath(params.database)
    if (params.add_decoys) {
        DECOYDATABASE(
            ch_db_for_decoy_creation_or_null
        )
        ch_searchengine_in_db = DECOYDATABASE.out.db_decoy
        ch_versions = ch_versions.mix(DECOYDATABASE.out.version.ifEmpty(null))
    }


    TMT(ch_fileprep_result.iso, CREATE_INPUT_CHANNEL.out.ch_expdesign, ch_searchengine_in_db)
    ch_ids_pmultiqc = ch_ids_pmultiqc.mix(TMT.out.ch_pmultiqc_ids)
    ch_consensus_pmultiqc = ch_consensus_pmultiqc.mix(TMT.out.ch_pmultiqc_consensus)
    ch_pipeline_results = ch_pipeline_results.mix(TMT.out.final_result)
    ch_msstats_in = ch_msstats_in.mix(TMT.out.msstats_in)
    ch_versions = ch_versions.mix(TMT.out.versions.ifEmpty(null))

    LFQ(ch_fileprep_result.lfq, CREATE_INPUT_CHANNEL.out.ch_expdesign, ch_searchengine_in_db)
    ch_ids_pmultiqc = ch_ids_pmultiqc.mix(LFQ.out.ch_pmultiqc_ids)
    ch_consensus_pmultiqc = ch_consensus_pmultiqc.mix(LFQ.out.ch_pmultiqc_consensus)
    ch_pipeline_results = ch_pipeline_results.mix(LFQ.out.final_result)
    ch_msstats_in = ch_msstats_in.mix(LFQ.out.msstats_in)
    ch_versions = ch_versions.mix(LFQ.out.versions.ifEmpty(null))

    DIA(ch_fileprep_result.dia, CREATE_INPUT_CHANNEL.out.ch_expdesign, FILE_PREPARATION.out.statistics)
    ch_pipeline_results = ch_pipeline_results.mix(DIA.out.diann_report)
    ch_msstats_in = ch_msstats_in.mix(DIA.out.msstats_in)
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

    methods_description    = WorkflowQuantms.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(FILE_PREPARATION.out.statistics)
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_quantms_logo = file("$projectDir/assets/nf-core-quantms_logo_light.png")

    SUMMARYPIPELINE (
        CREATE_INPUT_CHANNEL.out.ch_expdesign
            .combine(ch_pipeline_results.ifEmpty([]).combine(ch_multiqc_files.collect())
            .combine(ch_ids_pmultiqc.collect().ifEmpty([]))
            .combine(ch_consensus_pmultiqc.collect().ifEmpty([])))
            .combine(ch_msstats_in.ifEmpty([])),
        ch_multiqc_quantms_logo
    )
    multiqc_report      = SUMMARYPIPELINE.out.ch_pmultiqc_report.toList()

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
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
========================================================================================
    THE END
========================================================================================
*/
