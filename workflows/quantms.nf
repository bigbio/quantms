/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_quantms_pipeline'

// Main subworkflows imported from the pipeline TMT, LFQ, DIA
include { TMT } from './tmt'
include { LFQ } from './lfq'
include { DIA } from './dia'

// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
include { INPUT_CHECK } from '../subworkflows/local/input_check/main'
include { FILE_PREPARATION } from '../subworkflows/local/file_preparation/main'
include { CREATE_INPUT_CHANNEL } from '../subworkflows/local/create_input_channel/main'
include { DDA_ID } from '../subworkflows/local/dda_id/main'

// Modules import from the pipeline
include { PMULTIQC as SUMMARY_PIPELINE } from '../modules/local/pmultiqc/main'
include { GENERATE_DECOY_DATABASE } from '../modules/local/openms/generate_decoy_database/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/


workflow QUANTMS {

    main:

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
    ch_versions = ch_versions.mix(CREATE_INPUT_CHANNEL.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: File preparation
    //
    FILE_PREPARATION (
        CREATE_INPUT_CHANNEL.out.ch_meta_config_iso.mix(CREATE_INPUT_CHANNEL.out.ch_meta_config_lfq).mix(CREATE_INPUT_CHANNEL.out.ch_meta_config_dia)
    )

    ch_versions = ch_versions.mix(FILE_PREPARATION.out.versions.ifEmpty(null))

    FILE_PREPARATION.out.results
            .branch {
                dia: it[0].acquisition_method.contains("dia")
                iso: it[0].labelling_type.contains("tmt") || it[0].labelling_type.contains("itraq")
                lfq: it[0].labelling_type.contains("label free")
            }
            .set{ch_fileprep_result}
    //
    // WORKFLOW: Run main bigbio/quantms analysis pipeline based on the quantification type
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
        GENERATE_DECOY_DATABASE(
            ch_db_for_decoy_creation_or_null
        )
        ch_searchengine_in_db = GENERATE_DECOY_DATABASE.out.db_decoy
        ch_versions = ch_versions.mix(GENERATE_DECOY_DATABASE.out.versions.ifEmpty(null))
    }

    // Check that there is no duplicated search engines
    if (params.search_engines) {
        search_engines = params.search_engines.tokenize(',')
        if (search_engines.size() != search_engines.unique().size()) {
            error( "Duplicated search engines in the search_engines parameter: ${params.search_engines}" )
        }
    }

    // Only performing id_only subworkflows .
    if (params.id_only) {
        DDA_ID(FILE_PREPARATION.out.results, ch_searchengine_in_db, FILE_PREPARATION.out.ms2_statistics, CREATE_INPUT_CHANNEL.out.ch_expdesign)
        ch_versions = ch_versions.mix(DDA_ID.out.versions.ifEmpty(null))
        ch_ids_pmultiqc = ch_ids_pmultiqc.mix(DDA_ID.out.ch_pmultiqc_ids)
        ch_consensus_pmultiqc = ch_consensus_pmultiqc.mix(DDA_ID.out.ch_pmultiqc_consensus)
    } else {
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
        ch_pipeline_results = ch_pipeline_results.mix(DIA.out.final_result)
        ch_msstats_in = ch_msstats_in.mix(DIA.out.msstats_in)
        ch_versions = ch_versions.mix(DIA.out.versions.ifEmpty(null))
    }

    // Other subworkflow will return null when performing another subworkflow due to unknown reason.
    ch_versions = ch_versions.filter{ it != null }

    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'quantms_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    ch_multiqc_files                      = Channel.empty()
    ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo                       = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_multiqc_config)
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files                      = ch_multiqc_files.mix(FILE_PREPARATION.out.statistics)
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: false))
    ch_multiqc_quantms_logo               = file("$projectDir/assets/nf-core-quantms_logo_light.png")

    SUMMARY_PIPELINE (
        CREATE_INPUT_CHANNEL.out.ch_expdesign
            .combine(ch_pipeline_results.ifEmpty([]).combine(ch_multiqc_files.collect())
            .combine(ch_ids_pmultiqc.collect().ifEmpty([]))
            .combine(ch_consensus_pmultiqc.collect().ifEmpty([])))
            .combine(ch_msstats_in.ifEmpty([])),
        ch_multiqc_quantms_logo
    )

    emit:
    multiqc_report      = SUMMARY_PIPELINE.out.ch_pmultiqc_report.toList()
    versions            = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
